Finance::Quote Brazil
=====================

This is a set of Finance::Quote modules to fetch prices of Brazilian government
and private bonds, as well as mutual funds, which, unlike BM&F Bovespa stocks,
are not available through the standard modules.

Currently the following quoters are implemented:

* BMFBovespa: Private bonds
* SNDBrasil: Private bonds negotiated on the secondary market
* TNBrasil: Tesouro Direto (government bonds)

To-do
-----

* Add quoters for mutual funds of various banks.

Installation
------------

There's no package installer. Just copy the pm modules to
`/usr/local/lib/site_perl/Finance/Quote` and set the `FQ_LOAD_QUOTELET`
environment variable so that Gnucash loads those modules. For example:

```
export FQ_LOAD_QUOTELET="Currencies Yahoo::Brasil TNBrasil SNDBrasil BMFBovespa"
```
