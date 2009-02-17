# $Id: Makefile.PL,v 1.33 2007/12/10 04:45:18 danpb Exp $
# -*- perl -*-

use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
              NAME => "Test-AutoBuild",
              VERSION_FROM => 'lib/Test/AutoBuild.pm',
              AUTHOR => "Daniel Berrange (dan[at]berrange[dot]com)",
              EXE_FILES => ['bin/auto-build', 'bin/auto-build-make-root', 'bin/auto-build-clean-root'],
              NO_META => 1,
              PREREQ_PM => {
                  'BSD::Resource' => "1.10",
                  'Carp' => '0',
                  'Class::MethodMaker' => '0',
		  'Config' => '0',
		  'Cwd' => '0',
                  'Config::Record' => '1.1.0',
		  'Data::Dumper' => '0',
                  'Date::Manip' => '0',
                  'Digest::MD5' => '0',
                  'Fcntl' => '0',
                  'File::Copy' => '0',
                  'File::Find' => '0',
		  'File::Glob' => '0',
                  'File::Path' => '0',
		  'File::Spec' => '0',
		  'File::stat' => '0',
		  'IO::File' => '0',
                  'IO::Scalar' => '0',
		  'List::Util' => '0',
                  'Log::Log4perl' => "0",
                  'Net::SMTP' => "2.15",
                  'POSIX' => '0',
		  'Storable' => '0',
		  'Symbol' => '0',
                  'Sys::Hostname' => '0',
                  'Template' => '0',
		  'Test::More' => '0',
		  'XML::Simple' => '0',
              },
              dist =>
              {
                  COMPRESS => 'gzip --force --best',
              },
              clean =>
              {
                  FILES => '*.bak *~',
              },
              depend => {
                  Makefile => '$(VERSION_FROM)',
                  #'Test-AutoBuild.spec' => '$(VERSION_FROM)',
                  dist => 'Test-AutoBuild.spec META.yml',
              },
              realclean => {
                  FILES => 'Test-AutoBuild-*.tar.gz Test-AutoBuild.spec',
              },
              );

package MY;

sub libscan {
    my ($self, $path) = @_;
    ($path =~ /\~$/ || $path =~ m,/CVS/,) ? undef : $path;
}


sub postamble {
    '
WITH_SELINUX    = 0

sysconfdir      = $(PREFIX)/etc
bindir          = $(PREFIX)/bin
pkgsysconfdir   = $(sysconfdir)/auto-build.d
pkgdatadir      = $(PREFIX)/share/$(DISTNAME)-$(VERSION)
selinuxdir      = $(PREFIX)/share/selinux
selinuxpkgdir   = $(selinuxdir)/packages

# NB do not use prefix here
selinuxdevdir   = /usr/share/selinux/devel

pure_all ::
	test -d $(selinuxdevdir) -a $(WITH_SELINUX) = 1 && make -C conf/selinux ||:

clean ::
	test -d $(selinuxdevdir) -a $(WITH_SELINUX) = 1 && make -C conf/selinux clean ||:

install ::
	install -d -m 0755 $(pkgsysconfdir)
	for i in conf/*.conf ; do \
		conf=`echo $$i | sed -e \'s/conf\///\'`; \
		if [ -f $(pkgsysconfdir)/$$conf ]; then \
			install -c -m 0644 $$i $(pkgsysconfdir)/$$conf-example; \
			echo "Not overwriting existing config file $(pkgsysconfdir)/$$conf" ; \
		else \
			install -c -m 0644 $$i $(pkgsysconfdir)/$$conf; \
		fi \
	done
	install -d -m 0755 $(pkgsysconfdir)/engine
	for i in conf/engine/*.conf ; do \
	        conf=`echo $$i | sed -e \'s/conf\///\'`; \
	        if [ -f $(pkgsysconfdir)/$$conf ]; then \
	                install -c -m 0644 $$i $(pkgsysconfdir)/$$conf-example; \
	                echo "Not overwriting existing config file $(pkgsysconfdir)/$$conf" ; \
	        else \
	                install -c -m 0644 $$i $(pkgsysconfdir)/$$conf; \
	        fi \
	done
	install -d -m 0755 $(pkgsysconfdir)/cron
	for i in conf/cron/*.conf ; do \
	        conf=`echo $$i | sed -e \'s/conf\///\'`; \
	        if [ -f $(pkgsysconfdir)/$$conf ]; then \
	                install -c -m 0644 $$i $(pkgsysconfdir)/$$conf-example; \
	                echo "Not overwriting existing config file $(pkgsysconfdir)/$$conf" ; \
	        else \
	                install -c -m 0644 $$i $(pkgsysconfdir)/$$conf; \
	        fi \
	done
	install -d -m 0755 $(pkgsysconfdir)/httpd
	for i in conf/httpd/*.conf ; do \
	        conf=`echo $$i | sed -e \'s/conf\///\'`; \
	        if [ -f $(pkgsysconfdir)/$$conf ]; then \
	                install -c -m 0644 $$i $(pkgsysconfdir)/$$conf-example; \
	                echo "Not overwriting existing config file $(pkgsysconfdir)/$$conf" ; \
	        else \
	                install -c -m 0644 $$i $(pkgsysconfdir)/$$conf; \
	        fi \
	done
	install -d -m 0755 $(pkgsysconfdir)/templates
	install -c -m 0644 templates/*.txt $(pkgsysconfdir)/templates/
	install -c -m 0644 templates/*.html $(pkgsysconfdir)/templates/
	install -c -m 0644 templates/*.tt $(pkgsysconfdir)/templates/
	install -c -m 0644 templates/*.css $(pkgsysconfdir)/templates/
	install -c -m 0644 templates/*.rss $(pkgsysconfdir)/templates/
	install -c -m 0644 templates/*.png $(pkgsysconfdir)/templates/
	if [ -d $(selinuxdevdir) -a $(WITH_SELINUX) = 1 ]; then \
		install -d -m 0755 $(selinuxpkgdir)/auto-build/ ;\
		install -c -m 0644 conf/selinux/auto-build.pp $(selinuxpkgdir)/auto-build/auto-build.pp ;\
		install -c -m 0755 blib/script/auto-build $(bindir)/auto-build-secure ;\
	fi


HTMLDIR = blib/html

HTMLURLPREFIX = /
HTMLPODS = $(MAN3PODS:lib/%.pm=$(HTMLDIR)/%.html)

MAN5EXT = 5
INST_MAN5DIR = blib/man5

$(INST_MAN5DIR)/.exists :: $(INST_MAN3DIR)/.exists
	$(NOECHO) $(MKPATH) $(INST_MAN5DIR)
	$(NOECHO) $(EQUALIZE_TIMESTAMP) $(INST_MAN3DIR)/.exists $(INST_MAN5DIR)/.exists
	-$(NOECHO) $(CHMOD) $(PERM_RWX) $(INST_MAN5DIR)

all:: manify5pods

manify5pods: $(INST_MAN5DIR)/.exists conf/auto-build.conf.pod
	$(NOECHO) $(POD2MAN_EXE) --section=5 --perm_rw=$(PERM_RW)\
          conf/auto-build.conf.pod $(INST_MAN5DIR)/auto-build.conf.$(MAN5EXT)

INSTALLMAN5DIR = $(PERLPREFIX)/share/man/man5
DESTINSTALLMAN5DIR = $(DESTDIR)$(INSTALLMAN5DIR)
INSTALLSITEMAN5DIR = $(SITEPREFIX)/share/man/man5
DESTINSTALLSITEMAN5DIR = $(DESTDIR)$(INSTALLSITEMAN5DIR)
INSTALLVENDORMAN5DIR = $(VENDORPREFIX)/share/man/man5
DESTINSTALLVENDORMAN5DIR = $(DESTDIR)$(INSTALLVENDORMAN5DIR)

pure_perl_install ::
	install -d -m 0755 $(DESTINSTALLMAN5DIR)
	install -c -m 644 $(INST_MAN5DIR)/* $(DESTINSTALLMAN5DIR)

pure_site_install ::
	install -d -m 0755 $(DESTINSTALLSITEMAN5DIR)
	install -c -m 644 $(INST_MAN5DIR)/* $(DESTINSTALLSITEMAN5DIR)

pure_vendor_install ::
	install -d -m 0755 $(DESTINSTALLVENDORMAN5DIR)
	install -c -m 644 $(INST_MAN5DIR)/* $(DESTINSTALLVENDORMAN5DIR)


htmlifypods: $(HTMLDIR) $(HTMLPODS)

$(HTMLDIR):
	mkdir $@

$(HTMLDIR)/%.html: lib/%.pm
	mkdir -p `dirname $@`
	pod2html --htmlroot=$(HTMLURLPREFIX) --infile=$< --outfile=$@ --podpath=$(HTMLDIR)

';
}

sub test {
    my $self = shift;
    my $mm_test = $self->SUPER::test(@_);

    return '
test :: META.yml
' . $mm_test;
  }

__END__
