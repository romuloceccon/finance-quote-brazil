use strict;

package Finance::Quote::TNBrasil;

use List::Util qw( min );
use LWP::UserAgent;
use Spreadsheet::ParseExcel;
use HTML::TreeBuilder::XPath;

use vars qw/$TN_BASE_URL $VERSION $TN_QUOTES_INDEX/;

$VERSION = '0.1';
$TN_BASE_URL = 'http://www.tesouro.fazenda.gov.br/documents/10180/137713/';
$TN_QUOTES_INDEX = 'http://sisweb.tesouro.gov.br/apex/';

sub methods { return ( tesourodireto => \&tesourodireto ); }

{
  my @labels = qw/name last bid ask date isodate time price method exchange/;
  sub labels { return ( tesourodireto => \@labels ); }
}

sub _current_year {
  my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime;
  return $year + 1900;
}

sub tesourodireto {
  my $quoter = shift;
  my @symbols = @_;
  return unless @symbols;
  my %info;

  my $ua = $quoter->user_agent;
  my $parser = Spreadsheet::ParseExcel->new();
  my %books;
  my $year = sprintf "%d", _current_year;

  my %files;
  my $files_msg;
  my $files_resp = $ua->get($TN_QUOTES_INDEX . 'f?p=2031:2');
  if ($files_resp->code == 302) {
    my $index_url = $files_resp->header('Location');
    my $index_cookie = $files_resp->header('Set-Cookie');
    $index_cookie =~ s/;.*//;

    my $req = HTTP::Request->new(GET => $index_url);
    $req->header('Cookie' => $index_cookie);
    my $resp = $ua->request($req);

    if ($resp->is_success) {
      my $message = $resp->decoded_content;
      my $tree = HTML::TreeBuilder::XPath->new_from_content($message);

      my $cur_year = '0';
      foreach my $node ($tree->findnodes('/html/body//div[@class="apex-body"]' .
          '//div[@class="bl-body"]/child::node()')) {
        next unless ref($node) eq "HTML::Element";

        if ($node->tag() eq 'span') {
          $cur_year = $node->as_text();
          $cur_year =~ /(\d+)/;
          $cur_year = $1;
          next;
        }

        next if ($cur_year eq '0' or $node->tag() ne 'a');

        my $node_text = $node->as_text();
        $node_text =~ s/ /_/;
        $files{$cur_year}{$node_text} = $TN_QUOTES_INDEX . $node->attr('href');
      }
    }
    else {
      $files_msg = 'HTTP session failed while fetching index: ' . $resp->code;
    }
  }
  else {
    $files_msg = 'HTTP session failed while logging in: ' . $files_resp->code;
  }

  foreach my $symbol (@symbols) {
    if ($files_msg) {
      $info{$symbol, 'success'} = 0;
      $info{$symbol, 'errormsg'} = $files_msg;
      next;
    }

    my $file_year = $symbol;
    $file_year =~ /(\d\d)$/;
    $file_year = '20' . $1;
    $file_year = min $file_year, $year;

    my $tmp = reverse $symbol;
    $tmp =~ s/^.*?_//;
    my $symbol_base = reverse($tmp);
    my $filename = $symbol_base . ' (' . $file_year . ')';

    unless ($books{$filename}) {
      if (defined $files{$file_year} and defined $files{$file_year}{$symbol_base}) {
        my $book_resp = $ua->get($files{$file_year}{$symbol_base});

        if ($book_resp->is_success) {
          my $book = $parser->parse($book_resp->content_ref);

          if ($book) {
            $books{$filename}{'book'} = $book;
          }
          else {
            $books{$filename}{'error'} = 'Cannot parse book "' . $filename .
              '": ' . $parser->error();
          }
        }
        else {
          $books{$filename}{'error'} = 'HTTP session failed while fetching ' .
              'book "' . $filename . '": ' . $book_resp->code;
        }
      }
      else {
        $books{$filename}{'error'} = 'Cannot find book "' . $filename . '"';
      }
    }

    if ($books{$filename}{'error'}) {
      $info{$symbol, 'success'} = 0;
      $info{$symbol, 'errormsg'} = $books{$filename}{'error'};
      next;
    }

    my $book = $books{$filename}{'book'};

    my $name = $symbol;
    $name =~ s/_/ /g;
    $name =~ s/-//g if ($file_year < 2012);
    $name =~ s/Principal/Princ/ if ($file_year >= 2017);

    my $sheet = $book->worksheet($name);

    unless ($sheet) {
      $info{$symbol, 'success'} = 0;
      $info{$symbol, 'errormsg'} = "Symbol not found";
      next;
    }

    my ($date, $ask, $bid);

    for (my $r = 2; ; $r++) {
      my $cell_0 = $sheet->get_cell($r, 0);
      my $cell_3 = $sheet->get_cell($r, 3);
      my $cell_4 = $sheet->get_cell($r, 4);

      last unless defined $cell_0 && defined $cell_0->value();
      last unless defined $cell_3 && $cell_3->unformatted();
      last unless defined $cell_4 && $cell_4->unformatted();
      last unless $cell_3->unformatted() > 0.0 && $cell_4->unformatted() > 0.0;

      $date = $cell_0->value();
      $ask = sprintf "%.2f", $cell_3->unformatted();
      $bid = sprintf "%.2f", $cell_4->unformatted();
    }

    unless ($date) {
      $info{$symbol, 'success'} = 0;
      $info{$symbol, 'errormsg'} = "Symbol table empty";
      next;
    }

    $info{$symbol, 'symbol'} = $symbol;
    $info{$symbol, 'name'} = $name;
    $info{$symbol, 'last'} = $bid;
    $info{$symbol, 'ask'} = $ask;
    $info{$symbol, 'bid'} = $bid;
    my $datefmt = 'eurodate';
    $datefmt = 'isodate' if ($file_year < 2012);
    $quoter->store_date(\%info, $symbol, {$datefmt => $date});
    $info{$symbol, 'time'} = '12:00:00';

    $info{$symbol, 'currency'} = 'BRL';
    $info{$symbol, 'method'} = 'tesourodireto';
    $info{$symbol, 'exchange'} = 'BM&F Bovespa';
    $info{$symbol, 'price'} = $info{$symbol, 'ask'};
    $info{$symbol, 'success'} = 1;
  }

  return %info if wantarray;
  return \%info;
}

1;

=head1 NAME

Finance::Quote::TNBrasil - Get prices of Brazilian government bonds.

=head1 SYNOPSIS

Syntax for bond symbols are as follows:

* Tesouro Prefixado          => LTN_010121             (mat. 2021-01-01)
* Tesouro Prefixado c/ Juros => NTN-F_010123           (mat. 2023-01-01)
* Tesouro SELIC              => LFT_010321             (mat. 2021-03-01)
* Tesouro Inflação c/ Juros  => NTN-B_150535           (mat. 2035-05-15)
* Tesouro Inflação           => NTN-B_Principal_150824 (mat. 2024-08-15)

Example:

    use Finance::Quote;

    $q = Finance::Quote->new('TNBrasil');

    %bondinfo = $q->fetch('tesourodireto', 'LTN_010121', 'NTN-F_010123', ...);

=head1 DESCRIPTION

This module obtains the prices of Brazilian government bonds negotiated on BM&F
Bovespa, available at
http://www.tesouro.fazenda.gov.br/tesouro-direto-balanco-e-estatisticas.

HTML::TreeBuilder::XPath and Spreadsheet::ParseExcel are required. On
Debian/Ubuntu/Linux Mint execute:

    $ apt-get install libhtml-treebuilder-xpath-perl libspreadsheet-parseexcel-perl

If using the module via GnuCash install this file under
/usr/local/lib/site_perl/Finance/Quote and set FQ_LOAD_QUOTELET in your
environment (e.g. in ~/.xsessionrc):

    export FQ_LOAD_QUOTELET="Currencies Yahoo::Brasil TNBrasil"

=head1 LABELS RETURNED

The information returned may include: name, last, ask, bid, date, isodate,
time, currency, method, exchange and price. "last" will return the "bid" price;
"price" will return the "ask" price.

=head1 SEE ALSO

http://www.tesouro.fazenda.gov.br/tesouro-direto

=cut
