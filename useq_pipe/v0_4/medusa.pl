#!/usr/bin/perl -w

=head2 Authors

=head3 Created by

Gareth Wilson
gareth.wilson@cancer.ucl.ac.uk

=head2 Description
Central pipeline script for running MeDIP-seq DMR analysis from alignment through to calling DMRs.
=head2 Usage

Usage: ./medusa.pl

-p medusa configuration file
-t list of ids for treatment samples (comma separated)
-c list of ids for control samples (comma separated)
-h list options

=cut

#################################################################
# medusa.pl
#################################################################

use strict;
use warnings;
use Config::Simple;
use Getopt::Std;
use Parallel::ForkManager;

my ($config_file, $treats, $controls);

my %opts;
getopts('hp:t:c:',\%opts);

if (defined $opts{h})
{
       print <<USAGE;

Usage:
-p medusa configuration file
-t list of ids for treatment samples (comma separated)
-c list of ids for control samples (comma separated)
-h list options


USAGE
       exit;
}

if (defined $opts{p})
{
	$config_file = $opts{p};
}
else
{
	print <<USAGE;

Usage:
-p medusa configuration file
-t list of ids for treatment samples (comma separated)
-c list of ids for control samples (comma separated)
-h list options

USAGE
       exit;
}

if (defined $opts{t})
{
	$treats = $opts{t};
}
else
{
	print <<USAGE;

Usage:
-p medusa configuration file
-t list of ids for treatment samples (comma separated)
-c list of ids for control samples (comma separated)
-h list options

USAGE
       exit;
}

if (defined $opts{c})
{
	$controls = $opts{c};
}
else
{
	print <<USAGE;

Usage:
-p medusa configuration file
-t list of ids for treatment samples (comma separated)
-c list of ids for control samples (comma separated)
-h list options

USAGE
       exit;
}

# create a new object containing the variables in the cfg file
my $cfg = new Config::Simple($config_file);
# initialize the variables shared with the config file
my $pipe = $cfg->param(-block=>'PIPE');
my $part0 = $pipe->{part0};
my $part1 = $pipe->{part1};
my $part2 = $pipe->{part2};
my $part3 = $pipe->{part3};
my $part4 = $pipe->{part4};
my $part5 = $pipe->{part5};

my $fork = $cfg->param(-block=>'FORKS');
my $max_forks = $fork->{max_forks};

my $paths = $cfg->param(-block=>'PATHS');
my $path2scripts = $paths->{path2scripts};
my $path2reads = $paths->{path2reads};
my $path2genome_dir = $paths->{path2genome_dir};
my $path2alignment = $paths->{path2alignment};
my $path2useq = $paths->{path2useq};
my $path2features_dir = $paths->{path2features_dir};
my $path2features_list = $paths->{path2features_list};
my $path2repeats_list = $paths->{path2repeats_list};
my $path2annotation_output = $paths->{path2annotation_output};
my $path2dmr = $paths->{path2dmr};

my $genomes = $cfg->param(-block=>'GENOMES');
my $bwa_genome = $genomes->{bwa_genome};
my $fasta_genome = $genomes->{fasta_genome};
my $species = $genomes->{species};
my $ref_name = $genomes->{ref_name};
my $max_chrom = $genomes->{max_chrom};

my $reads = $cfg->param(-block=>'READS');
my $max_insert = $reads->{max_insert};
my $read_length = $reads->{read_length};

print "read = $read_length\n";

my $thresholds = $cfg->param(-block=>'THRESHOLDS');
my $min_read_depth = $thresholds->{minimum_read_depth};
my $min_fdr = $thresholds->{minimum_fdr};
my $intersect_threshold = $thresholds->{intersect_threshold};
my $upstream = $thresholds->{upstream_nearest_gene_threshold};
my $downstream = $thresholds->{downstream_nearest_gene_threshold};

my $norm = $cfg->param(-block=>'FRAGMENT_LENGTH');
my $normalised = $norm->{normalised};
my $norm_prefix = $norm->{prefix};

my $cnv = $cfg->param(-block=>'CNV');
my $cnv_correction = $cnv->{cnv_correction};
my $cnv_dir = $cnv->{cnv_dir};

# process the sample ids
my @treats = split/,/,$treats;
my @controls = split/,/,$controls;
# if just want to perform alignment and filtering can set controls as 0
my @samples;
if ($controls eq "0")
{
	@samples = @treats;
}
else
{
	@samples = (@treats,@controls);
}
# print copy of config file, plus sample info to path2alignment to keep as record

#check to see if $path2alignment exists, if not make directory
unless(-d $path2alignment)
{
	mkdir $path2alignment or die;
}

my $time = time();
my $tmp_cfg = "medusa_config_".$time.".txt";
open (OUT, ">$path2alignment/$tmp_cfg") or die "Can't open $path2alignment/$tmp_cfg for writing";
print OUT "Treatment samples = $treats\nControl samples = $controls\n\n";
open (IN, "$config_file" ) or die "Can't open $config_file for reading";
while (my $line = <IN>)
{
	print OUT $line;
}
close IN;
close OUT;

if ($part0)
{
        #check to see if $path2alignment exists, if not make directory
        unless(-d $path2alignment)
        {
		mkdir $path2alignment or die;
	}
	
	my $pm = new Parallel::ForkManager($max_forks);
	foreach my $child ( 0 .. $#samples )
	{
    		my $sample = $samples[$child];
		my $read1 = $sample."_1.fastq";
	        my $read2 = $sample."_2.fastq";
    		my $pid = $pm->start($sample) and next;
		# This code is the child process
		print "started alignment process for  $sample\n";
	        exec("$path2scripts/medusa_pipeline/medusa_pipe_pt0.sh $sample $path2reads $path2genome_dir $read1 $read2 $bwa_genome $fasta_genome $path2alignment $max_insert") or die "couldn't exec part 0 $sample";
	        print "done with alignment process for $sample\n";
		sleep 1;
		$pm->finish($child); # pass an exit code to finish
	}
	$pm->wait_all_children;
	print "End of pipe part 0\n";
}
if ($part1)
{
        #check to see if $path2useq exists, if not make directory
        unless(-d $path2useq)
        {
		mkdir $path2useq or die;
	}
	my $pm = new Parallel::ForkManager($max_forks);
	foreach my $child ( 0 .. $#samples )
	{
    		my $sample = $samples[$child];
		my $pid = $pm->start($sample) and next;
		# This code is the child process
		print "started further filtering and QC process for  $sample\n";
	        my $logout = "$path2useq/$sample"."_pipe_pt1.log";
	        exec("$path2scripts/medusa_pipeline/medusa_pipe_pt1.sh $sample $species $read_length $path2alignment $path2useq $path2scripts >$logout") or die "couldn't exec part 1 $sample";
	        print "done with filtering and QC process for $sample\n";
		sleep 1;
		$pm->finish($child); # pass an exit code to finish
	}
	$pm->wait_all_children;
	print "End of pipe part 1\n";
}
if ($part2)
{
	#check to see if $path2useq exists, if not make directory
        unless(-d $path2useq)
        {
		die "$path2useq doesn't exist";
	}
	my $samples_bed;
	foreach my $sample (@samples)
	{
		$samples_bed .= "$sample".".bed ";
	}
	print "Starting fragment length normalisation\n";
	system("perl $path2scripts/medusa_pipeline/medusa_pipe_pt2.pl $norm_prefix $path2useq $samples_bed");
	print "End of pipe part 2\n";
}
if ($part3)
{
        #check to see if $path2useq exists, if not make directory
        unless(-d $path2useq)
        {
		die "$path2useq doesn't exist";
	}
	my $pm = new Parallel::ForkManager($max_forks);
	foreach my $child ( 0 .. $#samples )
	{
    		my $sample;
    		if ($normalised)
		{
			$sample = $norm_prefix."_$samples[$child]";
		}
		else
		{
			$sample = $samples[$child];
		}
    		my $pid = $pm->start($sample) and next;
		# This code is the child process
		print "started preparing Point directories for $sample\n";
		exec("$path2scripts/medusa_pipeline/medusa_pipe_pt3.sh $sample $path2useq $ref_name") or die "couldn't exec part 3 $sample";
		print "done with preparing Point directories process for $sample\n";
		#print "This is $samples[$child], Child number $child\n";
		#sleep ( 2 * $child );
		#print "Sample $samples[$child] is about to get out...\n";
		sleep 1;
		$pm->finish($child); # pass an exit code to finish
	}
	$pm->wait_all_children;
	print "End of pipe part 3\n";
}
if ($part4)
{
	unless(-d $path2useq)
        {
		die "$path2useq doesn't exist";
	}
	my ($treat_cohort,$control_cohort,$mod);
	foreach my $t (@treats)
	{
		if ($normalised)
		{
			$mod = $norm_prefix."_$t"."_Point";
		}
		else
		{
			$mod = "$t"."_Point";
		}
		$treat_cohort .= $mod.",";
	}
	chop $treat_cohort;
	foreach my $c (@controls)
	{
		if ($normalised)
		{
			$mod = $norm_prefix."_$c"."_Point";
		}
		else
		{
			$mod = "$c"."_Point";
		}
		$control_cohort .= $mod.",";
	}
	chop $control_cohort;
	print "Starting DMR calling\n";
	if ($cnv_correction)
	{
		system("$path2scripts/medusa_pipeline/medusa_pipe_pt4_cnv.sh $treat_cohort $control_cohort $path2dmr $path2useq $min_read_depth $min_fdr $cnv_correction $cnv_dir $max_chrom");
	}
	else
	{
		system("$path2scripts/medusa_pipeline/medusa_pipe_pt4.sh $treat_cohort $control_cohort $path2dmr $path2useq $min_read_depth $min_fdr");
	}
	print "End of pipe part 4\n";
}
if ($part5)
{
	unless(-d "$path2dmr")
        {
		die "$path2dmr doesn't exist";
	}
	open (OUT, ">$path2dmr/sample.list") or die "Can't open $path2dmr/sample.list for writing";
	foreach my $sample (@samples)
	{
		print OUT "$sample\n";
	}
	close OUT;
	print "Starting DMR annotation\n";
	system("$path2scripts/medusa_pipeline/medusa_pipe_pt5.sh $path2dmr $path2genome_dir/$fasta_genome $path2features_dir/genes/genes.gff $upstream $downstream $path2features_dir $path2features_list $path2repeats_list $intersect_threshold $path2scripts/perl_scripts $path2annotation_output");
	print "End of pipe part 5\n";
}
