use strict;

package Finance::Quote::BMFBovespa;

use LWP::UserAgent;
use Time::Piece;
use Time::Seconds;
use HTML::TreeBuilder::XPath;

use vars qw/$BMF_URL $VERSION/;

$VERSION = '0.1';
$BMF_URL = 'http://bvmf.bmfbovespa.com.br/rendafixa/FormDetalhePUEmissor.asp';

sub methods { return ( bmfdebentures => \&bmfdebentures ); }

{
  my @labels = qw/name last date isodate time price method exchange/;
  sub labels { return ( bmfdebentures => \@labels ); }
}

sub bmfdebentures {
  my $quoter = shift;
  my @symbols = @_;
  return unless @symbols;
  my %info;

  my $ua = $quoter->user_agent;

  my $base_date = (localtime() - 30 * ONE_DAY)->strftime('%d%%2F%m%%2F%Y');

  for my $symbol (@symbols) {
    my $sym_param = $symbol;
    $sym_param =~ s/[-_]/%7C/;

    my $req = HTTP::Request->new(POST => $BMF_URL);
    $req->header('Content-Type' => 'application/x-www-form-urlencoded');

    my $post_data = 'cboCodEmissor=' . $sym_param . '&DataIni=' . $base_date;
    $req->content($post_data);

    my $resp = $ua->request($req);

    if (!$resp->is_success) {
      $info{$symbol, "success"} = 0;
      $info{$symbol, "errormsg"} = "HTTP session failed: " . $resp->code;

      next
    }

    my $message = $resp->decoded_content;
    my $tree= HTML::TreeBuilder::XPath->new_from_content($message);

    my $data;
    my $emissor;
    my $pu;

    foreach my $node ($tree->findnodes(
        '/html/body//div[@class="large-12 columns"]/table/tbody/tr[last()]')) {
      my $cols = $node->findnodes('./td');
      if ($cols->size() >= 4) {
        $data = $cols->[2]->as_text();
        $emissor = $cols->[0]->as_text();
        $pu = $cols->[3]->as_text();
      }
    }

    unless ($data) {
      $info{$symbol, "success"} = 0;
      $info{$symbol, "errormsg"} = "Symbol not found: " . $symbol;

      next
    }

    $info{$symbol, 'symbol'} = $symbol;
    $info{$symbol, 'name'} = $emissor;
    $info{$symbol, 'last'} = $pu;
    $quoter->store_date(\%info, $symbol, {eurodate => $data});
    $info{$symbol, 'time'} = '17:00:00';

    $info{$symbol, 'last'} =~ s/\.//g;
    $info{$symbol, 'last'} =~ s/,/./;

    $info{$symbol, 'currency'} = 'BRL';
    $info{$symbol, 'method'} = 'bmfdebentures';
    $info{$symbol, 'exchange'} = 'BM&F Bovespa';
    $info{$symbol, 'price'} = $info{$symbol, 'last'};
    $info{$symbol, 'success'} = 1;
  }

  return %info if wantarray;
  return \%info;
}

1;

=head1 NAME

Finance::Quote::BMFBovespa - Get prices of Brazilian private bonds (Bovespa).

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new('BMFBovespa');

    %bondinfo = $q->fetch('bmfdebentures', 'BOND1', 'BOND2', ...);

=head1 DESCRIPTION

This module obtains the prices of Brazilian private bonds negotiated on BM&F
Bovespa, available at www.bmfbovespa.com.br/pt-br/renda-fixa/preco-curva.aspx.

HTML::TreeBuilder::XPath is required. On Debian/Ubuntu/Linux Mint execute:

    $ apt-get install libhtml-treebuilder-xpath-perl

If using the module via GnuCash install this file under
/usr/local/lib/site_perl/Finance/Quote and set FQ_LOAD_QUOTELET in your
environment (e.g. in ~/.xsessionrc):

    export FQ_LOAD_QUOTELET="Currencies Yahoo::Brasil BMFBovespa"

=head1 LABELS RETURNED

The information returned may include: name, last, date, isodate, time, currency,
method, exchange and price. "price" will be set to the value of "last".

=head1 SEE ALSO

http://www.bmfbovespa.com.br/

=cut
