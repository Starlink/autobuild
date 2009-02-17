# -*- perl -*-
#

use strict;
use warnings;
use Cwd;
use File::Spec::Functions;
use File::Path;
use Test::More tests => 31;
use Log::Log4perl;
Log::Log4perl::init("t/log4perl.conf");

BEGIN {
  use_ok("Test::AutoBuild::Repository::Monotone") or die;
  use_ok("Test::AutoBuild::Runtime") or die;
  use_ok("Test::AutoBuild::Module") or die;
}


my $here = getcwd;
my $build_repos = catfile($here, "t", "build-repos");
my $build_home = catfile($here, "t", "build-home");
my $archive = catfile($here, "t", "110-Repository-Monotone.tar.gz");

END {
  unless ($ENV{DEBUG_TESTS}) {
    rmtree ($build_repos);
    rmtree ($build_home);
  }
}

rmtree ($build_repos);
rmtree ($build_home);

mkpath ([$build_repos, $build_home], 0, 0755);

my $repos;

SKIP: {

  my $found_mtn = 0;
  my $found_gunzip = 0;
  my $found_tar = 0;
  foreach my $dir (File::Spec->path) {
    my $mtn = catfile($dir, "mtn");
    $found_mtn = 1 if -x $mtn;
    my $gunzip = catfile($dir, "gunzip");
    $found_gunzip = 1 if -x $gunzip;
    my $tar = catfile($dir, "tar");
    $found_tar = 1 if -x $tar;
  }
  skip "mtn binary not in path", 28 unless $found_mtn;
  skip "gunzip binary not in path", 28 unless $found_gunzip;
  skip "tar binary not in path", 28 unless $found_tar;

  system "cd $build_repos && (gunzip -c $archive | tar xf -)";

  my $head = "main.db:trunk";
  my $branch = "main.db:wibble";

  chdir $build_home;
  $repos = Test::AutoBuild::Repository::Monotone->new(name => "test", label => "Test",
						      options => { 'path' => $build_repos});
  isa_ok($repos, "Test::AutoBuild::Repository::Monotone");


  &checkout("head", $head, 1197422028, "0\n", 1, {}, 1);
  &checkout("head", $head, 1197422039, "1\n", 1,
	    { "2007-12-12T01:13:57" => Test::AutoBuild::Change->new(number => "2007-12-12T01:13:57",
								    user => "fred\@example.com",
								    date => "1197422037",
								    files => ["a"],
								    description => "Change 1 on trunk")}, 1);

  &checkout("head", $head, 1197422050, "2\n", 1,
	    { "2007-12-12T01:14:08" => Test::AutoBuild::Change->new(number => "2007-12-12T01:14:08",
								    user => "fred\@example.com",
								    date => "1197422048",
								    files => ["a"],
								    description => "Change 2 on trunk")}, 2);

  #&checkout("head", $head, 1109844423, "2\n", 0, { }, 3 );
  &checkout("branch", $branch, 1197422061, "3\n", 1, { }, 3 );

  &checkout("head", $head, 1197422082, "4\n", 1,
	    { "2007-12-12T01:14:19" => Test::AutoBuild::Change->new(number => "2007-12-12T01:14:19",
								    user => "fred\@example.com",
								    date => "1197422059",
								    files => ["a"],
								    description => "Change 3 on branch"),
	      "2007-12-12T01:14:40" => Test::AutoBuild::Change->new(number => "2007-12-12T01:14:40",
								    user => "fred\@example.com",
								    date => "1197422080",
								    files => ["a"],
								    description => "Change 4 on trunk"), }, 4 );
  &checkout("branch", $branch, 1197422082, "3\n", 0, {}, 3);

  #&checkout("head", $head, 1109844447, "4\n", 0, { }, 7);
  &checkout("branch", $branch, 1197422093, "5\n", 1,
	    { "2007-12-12T01:14:51" => Test::AutoBuild::Change->new(number => "2007-12-12T01:14:51",
								    user => "fred\@example.com",
								    date => "1197422091",
								    files => ["a"],
								    description => "Change 5 on branch") }, 5 );

  &checkout("head", $head, 1197422205, "6\n", 1,
	    { "2007-12-12T01:14:51" => Test::AutoBuild::Change->new(number => "2007-12-12T01:14:51",
								    user => "fred\@example.com",
								    date => "1197422091",
								    files => ["a"],
								    description => "Change 5 on branch"),
	      "2007-12-12T01:16:32" => Test::AutoBuild::Change->new(number => "2007-12-12T01:16:32",
								    user => "fred\@example.com",
								    date => "1197422192",
								    files => ["a"],
								    description =>"propagate from branch 'wibble' (head b2578ec5695d59efbbf079d0f7fade1809f6ff03)\n" .
								                  "to branch 'trunk' (head b200826ef83ad0c78decfe2ef3512634629f87b0)"),
	      "2007-12-12T01:16:43" => Test::AutoBuild::Change->new(number => "2007-12-12T01:16:43",
								    user => "fred\@example.com",
								    date => "1197422203",
								    files => ["a"],
								    description => "Change 6 on trunk") }, 6 );

  &checkout("branch", $branch, 1197422205, "5\n", 0, {}, 5);

}

sub checkout {
  my $module = shift;
  my $src = shift;
  my $timestamp = shift;
  my $content = shift;
  my $expect_change = shift;
  my $expected_changes = shift;
  my $expect_root_change = shift;

  my $runtime = Test::AutoBuild::Runtime->new(counter => Test::Counter->new,
					      timestamp => $timestamp);

  my ($changed, $changes) = $repos->export($runtime, $src, $module);

  is($changed, $expect_change, $module . " files changed");
  is_deeply($changes, $expected_changes, $module . " changes match");

  my $file = catfile($build_home, $module, "a");
  open FILE, $file
    or die "cannot open $file: $!";

  my $line = <FILE>;
  close FILE;

  is($line, $content, $module . " content matches");
}

package Test::Counter;
use base qw(Test::AutoBuild::Counter);

sub generate {
  return 1;
}

