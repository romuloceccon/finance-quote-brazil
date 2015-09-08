use strict;

package Finance::Quote::TNBrasil;

use LWP::UserAgent;
use Spreadsheet::ParseExcel;

use vars qw/$TN_BASE_URL $VERSION/;

$VERSION = '0.1';
$TN_BASE_URL = 'http://www.tesouro.fazenda.gov.br/documents/10180/137713/';

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

  foreach my $symbol (@symbols) {
    my $tmp = reverse $symbol;
    $tmp =~ s/^.*?_//;
    my $filename = reverse($tmp) . '_' . $year . '.xls';

    unless ($books{$filename}) {
      my $resp = $ua->get($TN_BASE_URL . $filename);

      if ($resp->is_success) {
        my $book = $parser->parse($resp->content_ref);

        if ($book) {
          $books{$filename}{'book'} = $book;
        }
        else {
          $books{$filename}{'error'} = 'Cannot parse ' . $filename . ': ' . $parser->error();
        }
      }
      else {
        $books{$filename}{'error'} = 'HTTP session failed while fetching ' . $filename . ': ' . $resp->code;
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

      last unless defined $cell_0 && defined $cell_3 && defined $cell_4;
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
    $quoter->store_date(\%info, $symbol, {eurodate => $date});
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

Spreadsheet::ParseExcel is required. On Debian/Ubuntu/Linux Mint execute:

    $ apt-get install libspreadsheet-parseexcel-perl

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
