=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

 Please email comments or questions to the public Ensembl
 developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

 Questions may also be sent to the Ensembl help desk at
 <http://www.ensembl.org/Help/Contact>.

=cut

# EnsEMBL module for Bio::EnsEMBL::VEP::AnnotationSource::File
#
#

=head1 NAME

Bio::EnsEMBL::VEP::AnnotationSource::File - file-based annotation source

=cut


use strict;
use warnings;

package Bio::EnsEMBL::VEP::AnnotationSource::File;

use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Variation::Utils::VariationEffect qw(overlap);
use Bio::EnsEMBL::VEP::AnnotationSource::File::BED;

use base qw(Bio::EnsEMBL::VEP::AnnotationSource);

our $CAN_USE_TABIX_PM;

BEGIN {
  if (eval { require Bio::DB::HTS::Tabix; 1 }) {
    $CAN_USE_TABIX_PM = 1;
  }
  else {
    $CAN_USE_TABIX_PM = 0;
  }
}

my %FORMAT_MAP = (
  'vcf'     => 'VCF',
  'gff'     => 'GFF',
  'gtf'     => 'GTF',
  'bed'     => 'BED',
  'bigwig'  => 'BigWig',
);

my %VALID_TYPES = (
  'overlap' => 1,
  'exact' => 1,
);

sub new {
  my $caller = shift;
  my $class = ref($caller) || $caller;
  
  my $self = $class->SUPER::new(@_);

  my $hashref = $_[0];

  throw("ERROR: No file given\n") unless $hashref->{file};
  $self->file($hashref->{file});

  $self->short_name($hashref->{short_name} || (split '/', $self->file)[-1]);
  $self->type($hashref->{type} || 'overlap');
  $self->report_coords(defined($hashref->{report_coords}) ? $hashref->{report_coords} : 0);

  if(my $format = $hashref->{format}) {

    delete $hashref->{format};

    $format = lc($format);
    throw("ERROR: Unknown or unsupported format $format\n") unless $FORMAT_MAP{$format};

    throw("ERROR: Cannot use format $format without Bio::DB::HTS::Tabix module installed\n") unless $format eq 'bigwig' || $CAN_USE_TABIX_PM;

    my $class = 'Bio::EnsEMBL::VEP::AnnotationSource::File::'.$FORMAT_MAP{$format};
    return $class->new({%$hashref, config => $self->config});
  }

  return $self;
}

sub file {
  my $self = shift;
  $self->{file} = shift if @_;
  return $self->{file};
}

sub short_name {
  my $self = shift;
  $self->{short_name} = shift if @_;
  return $self->{short_name};
}

sub type {
  my $self = shift;

  if(@_) {
    my $new_type = shift;
    throw("ERROR: New type \"$new_type\" is not valid\n") unless $VALID_TYPES{$new_type};
    $self->{type} = $new_type;
  }

  return $self->{type};
}

sub report_coords {
  my $self = shift;
  $self->{report_coords} = shift if @_;
  return $self->{report_coords};
}

sub annotate_InputBuffer {
  my $self = shift;
  my $buffer = shift;

  my %by_chr;
  push @{$by_chr{$_->{chr}}}, $_ for @{$buffer->buffer};

  my $parser = $self->parser();

  foreach my $chr(keys %by_chr) {
    foreach my $vf(@{$by_chr{$chr}}) {
      my ($vf_start, $vf_end) = ($vf->{start}, $vf->{end});
      $parser->seek($chr, $vf_start - 1, $vf_end + 1);
      $parser->next();

      while($parser->{record} && $parser->get_start <= $vf_end) {
        $self->annotate_VariationFeature($vf);
        $parser->next();
      }
    }
  }
}

sub annotate_VariationFeature {
  my $self = shift;
  my $vf = shift;

  my $overlap_result = $self->_record_overlaps_VF($vf);

  push @{$vf->{_custom_annotations}->{$self->short_name}}, $self->_create_record($overlap_result) if $overlap_result;
}

sub _create_record {
  return {name => $_[0]->_get_record_name};
}

sub _get_record_name {
  my $self = shift;
  my $parser = $self->parser;

  return $self->report_coords ?
    sprintf(
      '%s:%i-%i',
      $parser->get_seqname,
      $parser->get_start,
      $parser->get_end
    ) :
    $parser->get_name;
}

sub _record_overlaps_VF {
  my $self = shift;
  my $vf = shift;

  my $parser = $self->parser();
  my $type = $self->type();

  if($type eq 'overlap') {
    return overlap($parser->get_start, $parser->get_end, $vf->{start}, $vf->{end});
  }
  elsif($type eq 'exact') {
    return $parser->get_start == $vf->{start} && $parser->get_end == $vf->{end};
  }

  return 0;
}

1;