use strict;

package Finance::Quote::HSBCBrasil;

use LWP::UserAgent;
use HTML::TreeBuilder::XPath;

use vars qw/$HSBC_URL $VERSION/;

$VERSION = '0.1';
$HSBC_URL = 'http://www.hsbc.com.br/1/2/br/para-voce/investimentos/tabela-de-rentabilidade';

sub methods { return ( hsbcfundos => \&hsbcfundos ); }

{
  my @labels = qw/name last date isodate time price method exchange/;
  sub labels { return ( hsbcfundos => \@labels ); }
}

sub hsbcfundos {
  my $quoter = shift;
  my @symbols = @_;
  return unless @symbols;
  my %info;

  my $ua = $quoter->user_agent;

  my $error;
  my @table;
  my $resp = $ua->get($HSBC_URL);

  if ($resp->is_success) {
    my $message = $resp->decoded_content;
    my $tree= HTML::TreeBuilder::XPath->new_from_content($message);
    @table = $tree->findnodes('/html/body//table[@id="tabelaRiscos"]/tr');
  }
  else {
    $error = "HTTP session failed: " . $resp->code;
  }

  for my $symbol (@symbols) {
    unless (@table) {
      $info{$symbol, "success"} = 0;
      $info{$symbol, "errormsg"} = $error;

      next
    }

    my $sym_param = $symbol;
    $sym_param =~ s/[-_]/ /g;

    my $data;
    my $cotacao;

    foreach my $node (@table) {
      my $cols = $node->findnodes('./td');
      next unless $cols->size() >= 16;
      my $fname = $cols->[0]->as_text();
      $fname =~ s/^\s+|\s+$//g;

      if ($sym_param eq $fname) {
        $data = $cols->[1]->as_text();
        $cotacao = $cols->[2]->as_text();
        last;
      }
    }

    unless ($data) {
      $info{$symbol, "success"} = 0;
      $info{$symbol, "errormsg"} = "Symbol not found: " . $symbol;

      next
    }

    $info{$symbol, 'symbol'} = $symbol;
    $info{$symbol, 'name'} = 'HSBC';
    $info{$symbol, 'last'} = $cotacao;
    $quoter->store_date(\%info, $symbol, {eurodate => $data});
    $info{$symbol, 'time'} = '17:00:00';

    $info{$symbol, 'last'} =~ s/\.//g;
    $info{$symbol, 'last'} =~ s/,/./;

    $info{$symbol, 'currency'} = 'BRL';
    $info{$symbol, 'method'} = 'hsbcfundos';
    $info{$symbol, 'exchange'} = 'Fundos HSBC';
    $info{$symbol, 'price'} = $info{$symbol, 'last'};
    $info{$symbol, 'success'} = 1;
  }

  return %info if wantarray;
  return \%info;
}
