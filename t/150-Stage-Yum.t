# -*- perl -*-

use Test::More tests => 4;
use warnings;
use strict;
use Log::Log4perl;

Log::Log4perl::init("t/log4perl.conf");

BEGIN {
  use_ok("Test::AutoBuild::Stage::Yum") or die;
  use_ok("Test::AutoBuild::Runtime") or die;
  use_ok("Test::AutoBuild::Counter::Time") or die;
}

my $runtime = Test::AutoBuild::Runtime->new(counter => Test::AutoBuild::Counter::Time->new());

TEST_YUM: {
  my $stage = Test::AutoBuild::Stage::Yum->new(name => "yum",
					       label => "Generate Yum Index",
					       options => {
							  });
  isa_ok($stage, "Test::AutoBuild::Stage::Yum");

  # Implement me!
  #$stage->run($runtime);
  #ok($stage->succeeded(), "stage succeeeded");
}
