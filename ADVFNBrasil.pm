use strict;

package Finance::Quote::ADVFNBrasil;

use LWP::UserAgent;
use HTML::TreeBuilder::XPath;

use vars qw/$VERSION $ADVFN_URL/;

$VERSION = '0.1';
$ADVFN_URL = 'https://br.advfn.com/common/search/exchanges/historical';

sub methods { return ( advfnbovespa => \&advfnbovespa ); }

{
  my @labels = qw/name last high low date isodate time volume price p_change
                  currency method exchange/;
  sub labels { return ( advfnbovespa => \@labels ); }
}

sub advfnbovespa {
  my $quoter = shift;
  my @symbols = @_;
  return unless @symbols;
  my %info;

  my $ua = $quoter->user_agent;

  my %months = ('Jan' => '01', 'Fev' => '02', 'Mar' => '03', 'Abr' => '04',
                'Mai' => '05', 'Jun' => '06', 'Jul' => '07', 'Ago' => '08',
                'Set' => '09', 'Out' => '10', 'Nov' => '11', 'Dez' => '12');

  for my $symbol (@symbols) {
    my $req_1 = HTTP::Request->new(POST => $ADVFN_URL);
    $req_1->header('Accept' => '*/*');
    $req_1->header('User-Agent' => 'Perl');
    $req_1->header('Content-Type' => 'application/x-www-form-urlencoded');

    $req_1->content("symbol_ok=OK&symbol=BOV:${symbol}");
    my $resp_1 = $ua->request($req_1);
    my $resp_1_st = $resp_1->code;

    if ($resp_1_st < 300 or $resp_1_st >= 400) {
      $info{$symbol, 'success'} = 0;
      $info{$symbol, 'errormsg'} = 'Unexpected response code while looking ' .
        'for symbol ' . ${symbol} . ': ' . $resp_1_st;
      next;
    }

    my $req_2 = HTTP::Request->new(GET => $resp_1->header('Location'));
    $req_2->header('User-Agent' => 'Perl');

    my $resp_2 = $ua->request($req_2);
    my $resp_2_st = $resp_2->code;

    if ($resp_2_st < 200 or $resp_2_st >= 300) {
      $info{$symbol, 'success'} = 0;
      $info{$symbol, 'errormsg'} = 'Unexpected response code while fetching ' .
        'historical data for symbol ' . ${symbol} . ': ' . $resp_2_st;
      next;
    }

    my $message = $resp_2->decoded_content;
    my $tree = HTML::TreeBuilder::XPath->new_from_content($message);
    my @tables;
    my $h_pos = -1;

    for my $node ($tree->findnodes('/html/body//div[@id="content"]/*')) {
      my $n_class = $node->attr('class');
      my %classes;
      %classes = map { $_ => 1 } split(/ /, $n_class) if $n_class;

      if ($node->tag ne 'div' or not exists($classes{'TableElement'})) {
        my $n_title = $node->as_text();
        $h_pos = @tables if ($node->tag eq 'a' and $h_pos < 0 and
                             $n_title =~ /Cota\xe7\xf5es Hist\xf3ricas/);
        next;
      }

      my @row;
      foreach my $col ($node->findnodes('.//tr[2]/td')) {
        push @row, $col->as_text();
      }
      push @tables, \@row;
    }

    if ($h_pos < 0 or @tables < $h_pos + 1 or @{$tables[0]} < 3 or
        @{$tables[$h_pos]} < 7) {
      $info{$symbol, 'success'} = 0;
      $info{$symbol, 'errormsg'} = 'Cannot find historical data for symbol ' .
        ${symbol};
      next;
    }

    my $date = $tables[$h_pos][0];
    $date =~ /(\w+)\W+(\w+)\W+(\w+)/;
    $date = "$1/" . $months{$2} . "/$3";

    $info{$symbol, 'name'} = $tables[0][0];
    $info{$symbol, 'last'} = $tables[$h_pos][1];
    $info{$symbol, 'high'} = $tables[$h_pos][5];
    $info{$symbol, 'low'}  = $tables[$h_pos][4];
    $quoter->store_date(\%info, $symbol, {eurodate => $date});
    $info{$symbol, 'time'}  = '18:00:00';
    $info{$symbol, 'p_change'}  = $tables[$h_pos][3];
    $info{$symbol, 'volume'}  = $tables[$h_pos][6];

    foreach my $label (qw/last high low p_change volume/) {
      my $v = $info{$symbol, $label};
      $v =~ s/\.|\+|%//g;
      $v =~ s/,/./;
      $info{$symbol, $label} = $v;
    }

    # ensure float numbers are rounded to 2 decimal positions
    foreach my $label (qw/last high low p_change/) {
      $info{$symbol, $label} = sprintf '%.2f', $info{$symbol, $label};
    }

    $info{$symbol, 'currency'}  = 'BRL';
    $info{$symbol, 'method'}  = 'advfnbovespa';
    $info{$symbol, 'exchange'}  = $tables[0][2];
    $info{$symbol, 'price'} = $info{$symbol, 'last'};
    $info{$symbol, 'success'}  = 1;
  }

  return %info if wantarray;
  return \%info;
}

=head1 NAME

Finance::Quote::ADVFNBrasil - Get prices of Brazilian stocks (Bovespa).

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new('ADVFNBrasil');

    %stockinfo = $q->fetch('', 'SEER3', 'QGEP3', ...);

=head1 DESCRIPTION

This module obtains the prices of Brazilian stocks negotiated on Bovespa,
available at https://br.advfn.com/.

HTML::TreeBuilder::XPath is required. On Debian/Ubuntu/Linux Mint execute:

    $ apt-get install libhtml-treebuilder-xpath-perl

If using the module via GnuCash install this file under
/usr/local/lib/site_perl/Finance/Quote and set FQ_LOAD_QUOTELET in your
environment (e.g. in ~/.xsessionrc):

    export FQ_LOAD_QUOTELET="Currencies Yahoo::Brasil ADVFNBrasil"

=head1 LABELS RETURNED

The information returned may include: name, last, high, low, date, isodate,
time, volume, price, p_change, currency, method and exchange. "price" will be
set to the value of "last".

=head1 SEE ALSO

https://br.advfn.com/

=cut
