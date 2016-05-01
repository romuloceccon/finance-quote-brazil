Finance::Quote Brazil
=====================

This is a set of Finance::Quote modules to fetch prices of Brazilian government
and private bonds, as well as mutual funds, which, unlike BM&F Bovespa stocks,
are not available through the standard modules.

Currently the following quoters are implemented:

* BMFBovespa: Private bonds
* SNDBrasil: Private bonds negotiated on the secondary market
* TNBrasil: Tesouro Direto (government bonds)
* HSBCBrasil: Mutual funds from HSBC Brasil bank
* VAM: Mutual funds from Votorantim Asset Management

Installation
------------

There's no package installer. Just copy the pm modules to
`/usr/local/lib/site_perl/Finance/Quote` and set the `FQ_LOAD_QUOTELET`
environment variable so that Gnucash loads those modules. For example:

```
export FQ_LOAD_QUOTELET="Currencies Yahoo::Brasil TNBrasil SNDBrasil BMFBovespa"
```

Symbol names
------------

Bond and mutual fund symbols are sometimes not available. In those cases a "fake
symbol" – usually formed by replacing _spaces_ with _underscores_ – should be
supplied to the quoter. For example:

* BMFBovespa: use real symbol
  * _TRIA-DEB22_ ⇒ `TRIA-DEB22`

* SNDBrasil: use real symbol
  * _ITAP13_ ⇒ `ITAP13`

* TNBrasil: use official name (†) followed by maturity date in _ddmmyy_ format
  * _Tesouro IPCA+ 2019_ ⇒ `NTN-B_Principal_150519`
  * _Tesouro Selic 2021_ ⇒ `LFT_010321`

* HSBCBrasil:
  * _HSBC FIC FI RF CURTO PRAZO_ ⇒ `HSBC_FIC_FI_RF_CURTO_PRAZO`

* VAM:
  * _FIA Dividendos_ ⇒ `FIA_Dividendos`

(†) Nicknames and official names for Brazilian government bonds are as follows:

* Tesouro Prefixado ⇒ LTN
* Tesouro Selic ⇒ LFT
* Tesouro Prefixado com Juros Semestrais ⇒ NTN-F
* Tesouro IPCA+ ⇒ NTN-B Principal
* Tesouro IPCA+ com Juros Semestrais ⇒ NTN-B

Debugging
---------

If you have any issues trying to obtain quotes (from an interactive application
like GnuCash) the script `bin/getquote.pl` may help with debugging. For example:

    $ getquote.pl tesourodireto LFT_010321
    LFT_010321: 7707.61 @ 2016-04-29 (last)

    $ getquote.pl bmfdebentures TRIA-DEB22
    TRIA-DEB22: 15131.170000 @ 2016-04-29 (last)

    $ getquotes.pl vamfundos FIA_Dividendos
    FIA_Dividendos: 0.701088117 @ 2016-04-28 (last)

To-do
-----

* Add quoters for mutual funds of various banks.

License
-------

Released under MIT License. See `LICENSE` for details.
