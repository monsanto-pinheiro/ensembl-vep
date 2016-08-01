# Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;

use Test::More;
use Test::Exception;
use FindBin qw($Bin);

use lib $Bin;
use VEPTestingConfig;
my $test_cfg = VEPTestingConfig->new();

## BASIC TESTS
##############

# use test
use_ok('Bio::EnsEMBL::VEP::AnnotationSource::File');

my $as = Bio::EnsEMBL::VEP::AnnotationSource::File->new({file => 'test'});
ok($as, 'new is defined');

is_deeply(
  Bio::EnsEMBL::VEP::AnnotationSource::File->new({
    file => 'foo/bar',
    type => 'exact',
    report_coords => 1,
  }),
  bless({
    file => 'foo/bar',
    type => 'exact',
    short_name => 'bar',
    report_coords => 1,
  }, 'Bio::EnsEMBL::VEP::AnnotationSource::File'),
  'new - test settings'
);


throws_ok {Bio::EnsEMBL::VEP::AnnotationSource::File->new} qr/No file given/, 'new - no file';

throws_ok {Bio::EnsEMBL::VEP::AnnotationSource::File->new({file => 'foo', type => 'bar'})} qr/New type .+ is not valid/, 'new - invalid type';



## METHODS
##########

is($as->file, 'test', 'file - get');
is($as->file('foo/bar'), 'foo/bar', 'file - set');

$as = Bio::EnsEMBL::VEP::AnnotationSource::File->new({file => 'foo/bar'});
is($as->short_name, 'bar', 'short_name - get default');
is($as->short_name('foo'), 'foo', 'short_name - set');

$as = Bio::EnsEMBL::VEP::AnnotationSource::File->new({file => 'test'});
is($as->type, 'overlap', 'type - get default');
is($as->type('exact'), 'exact', 'type - set');
throws_ok {$as->type('foo')} qr/New type .+ is not valid/, 'type - invalid set';

is($as->report_coords, 0, 'report_coords - get default');
is($as->report_coords(1), 1, 'report_coords - set');

done_testing();
