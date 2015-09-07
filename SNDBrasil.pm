use strict;

package Finance::Quote::SNDBrasil;

use LWP::UserAgent;
use HTML::TreeBuilder::XPath;

use vars qw/$SND_URL $VERSION/;

$VERSION = '0.1';
$SND_URL = 'http://www.debentures.com.br/exploreosnd/consultaadados/mercadosecundario/precosdenegociacao_r.asp';

sub methods { return ( snddebentures => \&snddebentures ); }

{
  my @labels = qw/name last high low date isodate time volume price method exchange/;
  sub labels { return ( snddebentures => \@labels ); }
}

sub snddebentures {
  my $quoter = shift;
  my @symbols = @_;
  return unless @symbols;
  my %info;

  my $ua = $quoter->user_agent;

  for my $symbol (@symbols) {
    my $req = HTTP::Request->new(POST => $SND_URL);
    $req->header('Content-Type' => 'application/x-www-form-urlencoded');

    my $post_data = 'op_exc=False&emissor=&ativo=' . $symbol . '&ISIN=&dt_ini=&dt_fim=&Submit32.x=30&Submit32.y=15';
    $req->content($post_data);

    my $resp = $ua->request($req);

    if (!$resp->is_success) {
      $info{$symbol, "success"} = 0;
      $info{$symbol, "errormsg"} = "HTTP session failed: " . $resp->code;

      next
    }

    my $message = $resp->decoded_content;
    my $tree= HTML::TreeBuilder::XPath->new_from_content($message);

    my $data = '';
    my $emissor = '';
    my $ativo = '';
    my $isin = '';
    my $qtd = '';
    my $neg = '';
    my $preco_min = '';
    my $preco_med = '';
    my $preco_max = '';
    my $pu_da_curva = '';

    foreach my $node ($tree->findnodes('/html/body//table[@class="Ver10666666_cab"]')) {
      foreach my $row ($node->findnodes('./tr')) {
        my $cols = $row->findnodes('./td');
        if ($cols->size() == 20 && !($cols->[0]->as_text() eq 'Data')) {
          $data = $cols->[0]->as_text();
          $emissor = $cols->[2]->as_text();
          $ativo = $cols->[4]->as_text();
          $isin = $cols->[6]->as_text();
          $qtd = $cols->[8]->as_text();
          $neg = $cols->[10]->as_text();
          $preco_min = $cols->[12]->as_text();
          $preco_med = $cols->[14]->as_text();
          $preco_max = $cols->[16]->as_text();
          $pu_da_curva = $cols->[18]->as_text();
        }
      }
    }

    if ($data eq '') {
      $info{$symbol, "success"} = 0;
      $info{$symbol, "errormsg"} = "Symbol not found: " . $symbol;

      next
    }

    $info{$symbol, 'symbol'} = $symbol;
    $info{$symbol, 'name'} = $emissor;
    $info{$symbol, 'last'} = $preco_med;
    $info{$symbol, 'high'} = $preco_max;
    $info{$symbol, 'low'} = $preco_min;
    $quoter->store_date(\%info, $symbol, {eurodate => $data});
    $info{$symbol, 'time'} = '17:00:00';
    $info{$symbol, 'volume'} = $qtd;

    foreach my $label (qw/last high low volume/) {
      $info{$symbol, $label} =~ s/\.//;
      $info{$symbol, $label} =~ s/,/./;
    }

    $info{$symbol, 'currency'} = 'BRL';
    $info{$symbol, 'method'} = 'snddebentures';
    $info{$symbol, 'exchange'} = 'Sistema Nacional de Debêntures';
    $info{$symbol, 'price'} = $info{$symbol, 'last'};
    $info{$symbol, 'success'} = 1;
  }

  return %info if wantarray;
  return \%info;
}
