Fabulator
=========

Fabulator is an extension to the [Radiant CMS][] for creating web applications
that manage data in a set of RDF models.  The applications are written in an
XML language that describes the set of application views and the data that
triggers a move from one view to the next, along with initial conditions for
the application and data transformations that may store data in the RDF models.

Installation
------------

Installation is done in the usual manner for Radiant extensions.

This extension requires Radiant 0.9 or higher as well as the following
libraries:

* Redland RDF Ruby bindings (for RDF parsing)
* xml/libxml (GNOME XML library bindings)
* ruby-fabulator gem
* rgl gem

You may also want to add some fabulator extensions.
See http://github.com/jgsmith/

FreeBSD
-------

The Fabulator extension and plugins are developed on FreeBSD.  There are a
number of things to note when installing on FreeBSD.  The Redland Ruby
bindings seem to be broken if installing from a package.  The xml/libxml
and xslt packages might have a few issues as well.  Keep an eye on where
files are placed in case Ruby thinks they need to be somewhere else.

[Radiant CMS]: http://www.radiantcms.org/
