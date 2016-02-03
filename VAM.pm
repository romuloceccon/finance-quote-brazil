use strict;

package Finance::Quote::VAM;

use LWP::UserAgent;
use HTML::TreeBuilder::XPath;

use vars qw/$VAM_URL $VERSION/;

$VERSION = '0.1';
$VAM_URL = 'http://www.vam.com.br/web/site/pt/solucoes/parceiros_distribuidores/fundos_investimento/cotas_diarias.html';

sub methods { return ( vamfundos => \&vamfundos ); }

{
  my @labels = qw/name last date isodate time price method exchange/;
  sub labels { return ( vamfundos => \@labels ); }
}

sub vamfundos {
  my $quoter = shift;
  my @symbols = @_;
  return unless @symbols;
  my %info;

  my $ua = $quoter->user_agent;

  my $error;
  my @table;
  my $resp = $ua->get($VAM_URL);

  if ($resp->is_success) {
    my $message = $resp->decoded_content;
    my $tree= HTML::TreeBuilder::XPath->new_from_content($message);
    @table = $tree->findnodes('/html/body//table[@class="tabela02"]/tr[@class=""]');

    $error = "Could not find data nodes" unless (@table);
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
      next unless $cols->size() >= 3;
      my $fname = $cols->[0]->as_text();
      utf8::decode($sym_param);
      $fname =~ s/^\s+|\s+$//g;

      if ($sym_param eq $fname) {
        $cotacao = $cols->[1]->as_text();
        $data = $cols->[2]->as_text();
        last;
      }
    }

    unless ($data) {
      $info{$symbol, "success"} = 0;
      $info{$symbol, "errormsg"} = "Symbol not found: " . $symbol;

      next
    }

    $info{$symbol, 'symbol'} = $symbol;
    $info{$symbol, 'name'} = 'VAM';
    $info{$symbol, 'last'} = $cotacao;
    $quoter->store_date(\%info, $symbol, {eurodate => $data});
    $info{$symbol, 'time'} = '17:00:00';

    $info{$symbol, 'last'} =~ s/\.//g;
    $info{$symbol, 'last'} =~ s/,/./;

    $info{$symbol, 'currency'} = 'BRL';
    $info{$symbol, 'method'} = 'vamfundos';
    $info{$symbol, 'exchange'} = 'Fundos VAM';
    $info{$symbol, 'price'} = $info{$symbol, 'last'};
    $info{$symbol, 'success'} = 1;
  }

  return %info if wantarray;
  return \%info;
}

1;

=head1 NAME

Finance::Quote::VAM - Get quotes for mutual funds managed by Votorantim Asset
Management.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new('VAM');

    %bondinfo = $q->fetch('vamfundos', 'FUND1', 'FUND2', ...);

=head1 DESCRIPTION

This module obtains the prices of Votorantim Asset Management mutual funds,
available at http://www.vam.com.br/web/site/pt/solucoes/
parceiros_distribuidores/fundos_investimento/cotas_diarias.html

HTML::TreeBuilder::XPath is required. On Debian/Ubuntu/Linux Mint execute:

    $ apt-get install libhtml-treebuilder-xpath-perl

If using the module via GnuCash install this file under
/usr/local/lib/site_perl/Finance/Quote and set FQ_LOAD_QUOTELET in your
environment (e.g. in ~/.xsessionrc):

    export FQ_LOAD_QUOTELET="Currencies Yahoo::Brasil VAM"

=head1 LABELS RETURNED

The information returned may include: name, last, date, isodate, time, currency,
method, exchange and price. "price" will be set to the "last" value.

=head1 SEE ALSO

http://www.vam.com.br

=cut
