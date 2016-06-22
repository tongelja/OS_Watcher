#!/usr/bin/perl 
#
#####################################
#####################################
##
## Usage	: 
## Purpose	: 
## Returns	: 
## Parameters	: 
## Throws	: 
## Comments	: 
## See also	:
##
##
###################################################
###################################################



use strict;
use warnings;
use Carp;
use Getopt::Long;
use Pod::Usage;


###############################################
################################################
####
####
#### main()
####
#### Set variables
#### Get options from command line
#### Run parsing function
####
####
##################################################
##################################################

my $help = my $man = 0;
my $page_size = 30;

my $input_file;
my $input_time;
my $input_search;
my $input_type;
my $input_osw;
my $input_limit;
my $show_all_values;
my $input_skip;
my $input_opt1;
my $input_opt2;
my $input_opt3;
my $input_opt4;
my $input_opt5;

my %parse = ( meminfo        => \&parse_meminfo,
              vmstat         => \&parse_vmstat,  
              iostat         => \&parse_iostat,
              mpstat         => \&parse_mpstat,
              netstat        => \&parse_netstat,
              tracert        => \&parse_tracert,
              top            => \&parse_top,
              slabinfo       => \&parse_slabinfo,
              ps             => \&parse_ps,
              vxstat         => \&parse_vxstat,
            );


GetOptions ( 'f=s'             => \$input_file,
             't=s'             => \$input_time,
             's=s'             => \$input_search, 
             'o=s'             => \$input_osw,
             'l=i'             => \$input_limit,
             'y=s'             => \$input_type,
             'k=i'             => \$input_skip,
             'io_await=i'      => \$input_opt1,
             'io_svc=i'        => \$input_opt2,
             'io_util=i'       => \$input_opt3,
             'io_rd=i'         => \$input_opt4,
             'io_wrt=i'        => \$input_opt5,
             'vm_rq=i'         => \$input_opt1,
             'top_active'      => \$input_opt1,
             'top_list'        => \$input_opt2,
             'ps_pid=i'        => \$input_opt1,
             'ps_state=s'      => \$input_opt2,
             'ps_mem=i'        => \$input_opt3,
             'ps_cpu=i'        => \$input_opt4,
             'v'               => \$show_all_values,
             'help|?|usage'    => \$help,
             'man'             => \$man        );


pod2usage(1)                         if $help;
pod2usage(-exit => 0, -verbose => 2) if $man; 
$input_time   = '.*'                   if !defined $input_time;
$input_search = '.*'                   if !defined $input_search;
$input_limit  = 0                      if !defined $input_limit;;
$input_type   = 'DEFAULT'              if !defined $input_type;


croak "\nFile not specified.  Exiting script.\n"     if ( ! defined $input_file ) ;
croak "\nOSW type not found.\n"                      if ( ! defined $parse{$input_osw} );

 
$parse{$input_osw}->($input_file, $input_time, $input_search, $input_type, $input_limit, $show_all_values, $input_skip, $input_opt1, $input_opt2, $input_opt3, $input_opt4, $input_opt5 );

exit;



####################
#################
##
##
## Functions/Procedures
##
##
#########################
#########################

sub parse_meminfo {

    my ($input_file, $input_time, $input_search, $input_type, $input_limit, $show_all_values, $input_skip ) = @_;

    open my $INPUT_FILE, '<', $input_file or croak "Can't open file: $input_file\n";
    
    my $transaction_number   = 0;
    my %record;
    my %statistic;
    my $time;
    
    my %bytes = ( kb => 1024,
                  mb => 1024*1024,
                  gb => 1024*1024*1024 );
    
                 
    my $format = "%-18s %-18s %-18s %-18s \n";
     
    while (my $line = <$INPUT_FILE>) {
        chomp $line;
    
        if ( $line =~ m{^zzz.*$}mx ) {                              ## zzz signifies the start of a new transaction in the log file
            $transaction_number += 1;
            #($time) =  $line =~ m{(\d{2}:\d{2}:\d{2})}xms;
            ($time) =  $line =~ m{(\w+\s+\d+\s+\d{2}:\d{2}:\d{2})}xms;
            next;
        }
    
        next if ( !defined $time );
        next if ( $time !~ m/$input_time/xms );
     
        if ( my ($name, $value, $factor) = $line =~ m/([\w\s]+) : \s+ (\d+) \s+ (\w*) $ /xms) {
    
            next if ( $name !~ m/$input_search/ixms );
    
            if ( defined $factor ) {
                $record{$time}{$name} = $value * $bytes{ lc($factor) } ; }
            else {
                $record{$time}{$name} = $value; }
            
        }
    }
    
    
    close $INPUT_FILE;
    
    
    my $prev_i;
    my $counter = 0;
    
    TIME: for my $i ( sort keys %record ) {
        STAT: for my $j ( sort keys %{ $record{$i} } ) {
            if ( ! defined $prev_i ) {
                $prev_i = $i;
                next TIME;
            } 
            print_headers($input_osw, $counter, $format);
            next if ( ($record{$i}{$j} - $record{$prev_i}{$j}) < $input_limit );
            printf "$format", "$i", "$j", format_number( $record{$i}{$j}, 1024 ),  commify( $record{$i}{$j} - $record{$prev_i}{$j} );
            $counter++;
        }
        $prev_i = $i;
    }
}



sub parse_vmstat {

    my ($input_file, $input_time, $input_search, $input_type, $input_limit, $show_all_values, $input_skip, $input_rq ) = @_;
 
    my $format       = "%-19s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s\n";
    my $format_cpu   = "%-19s %-10s %-10s %-10s %-10s %-10s %-10s\n";
    my $format_mem   = "%-19s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s \n";
    my $format_disk  = "%-19s %-12s %-12s %-12s %-12s %-12s %-12s %-12s %-12s %-12s %-12s %-12s \n";
    my $format_stats = "%-19s %-40s %-10s \n";
    my $format_slab  = "%-19s %-40s %-10s %-10s %-10s %-10s \n";
    
    my $time;
    my $long_time;
    my %record;
    my $count;
 
    $input_rq      = 0     if ( ! defined $input_rq );
    $input_skip    = -1    if !$input_skip; 
    
    ## Get info from file
    ##
    open my $INPUT_FILE, '<', $input_file or croak "Can't open file: $input_file\n";
    
    
    my %line_num;
    my $trans_number  = 0;
    my $counter       = 0;
    
    my %vmstat_type  = ( slab   => 'vmstat_slab_info',
                         disk   => 'vmstat_disk',
                         stat   => 'vmstat_stats',
                         cpu    => 'vmstat_cpu', 
                         memory => 'vmstat_memory', );
    
    $count=0; 
    while (my $line = <$INPUT_FILE>) {
        chomp $line;
    
        if ($line =~ m{^zzz.*$}mx) {                              ## zzz signifies the start of a new transaction in the log file
            $line_num{cpu}    = 0;
            $line_num{disk}   = 0;
    
            $trans_number += 1;
    
            #($time)      =  $line =~ m{(\d{2}:\d{2}:\d{2})}xms;
            ($time) =  $line =~ m{(\w+\s+\d+\s+\d{2}:\d{2}:\d{2})}xms;
            next;
        }
       
        next   if ( !defined $time );
        next   if ( $time !~ m/$input_time/xms );
  
        $count++;
        next if  ( $count%$input_skip != 0 );
 
        ###
        ### CPU/Mem
        ###
        if ( $input_type =~ m/(?:CPU|MEMORY|DEFAULT)/i ) {
            if ( my ($r,    $b,     $swpd, $free, 
                     $buff, $cache, $si,   $so, 
                     $bi,   $bo,    $in,   $cs, 
                     $us,   $sy,    $id,   $wa,  $st) = $line =~ m/^\s*
                                                                   (\d+)\s+ (\d+)\s+ (\d+)\s+ (\d+)\s+
                                                                   (\d+)\s+ (\d+)\s+ (\d+)\s+ (\d+)\s+
                                                                   (\d+)\s+ (\d+)\s+ (\d+)\s+ (\d+)\s+
                                                                   (\d+)\s+ (\d+)\s+ (\d+)\s+ (\d+)\s+ (\d+)
                                                                   \s*$
                                                                  /xms ) {
        
                ##
                ## 1st line in multi-line vmstat is a 
                ## system average.  We don't need the 
                ## system average, we just need current stats.
                ##
                #if ( $line_num{cpu} != 2 ) {
                #     $line_num{cpu}++;
                #     next;
                #}

                $line_num{cpu}++;
                next   if ( $r < $input_rq );
        
                if ( $input_type =~ m/(?:DEFAULT|CPU)/i ) {
    
                    my $type = $vmstat_type{cpu};
    
                    $record{$time . '.' . $line_num{cpu}}{$type}{r}  = $r;
                    $record{$time . '.' . $line_num{cpu}}{$type}{b}  = $b;
                    $record{$time . '.' . $line_num{cpu}}{$type}{us} = $us;
                    $record{$time . '.' . $line_num{cpu}}{$type}{sy} = $sy;
                    $record{$time . '.' . $line_num{cpu}}{$type}{id} = $id;
                    $record{$time . '.' . $line_num{cpu}}{$type}{wa} = $wa;
                    $record{$time . '.' . $line_num{cpu}}{$type}{st} = $st;
                }
        
                if ( $input_type =~ m/MEMORY/i ) {
    
                    my $type=$vmstat_type{memory};
    
                    $record{$time}{$type}{swpd}  = $swpd;
                    $record{$time}{$type}{free}  = $free;
                    $record{$time}{$type}{buff}  = $buff;
                    $record{$time}{$type}{cache} = $cache;
                    $record{$time}{$type}{si}    = $si;
                    $record{$time}{$type}{so}    = $so;
                    $record{$time}{$type}{bi}    = $bi;
                    $record{$time}{$type}{bo}    = $bo;
                    $record{$time}{$type}{in}    = $in;
                    $record{$time}{$type}{cs}    = $cs;
                }
        
                $counter += 1;
            }
        }
    
    
        ###
        ### Disk
        ###
        if ( $input_type =~ m/DISK/i ) {
            my $type=$vmstat_type{disk};
    
            if ( my ($disk,    $r_total,  $r_merged,  $r_sectors, 
                     $r_ms,    $w_total,  $w_merged,  $w_sectors, 
                     $w_ms,    $io_cur,  $io_sec ) = $line =~ m/^\s*
                                                                ([\w-]+)\s+ (\d+)\s+ (\d+)\s+ (\d+)\s+ (\d+)\s+
                                                                (\d+)\s+     (\d+)\s+ (\d+)\s+ (\d+)\s+
                                                                (\d+)\s+     (\d+)
                                                                \s*$
                                                               /xms ) {
            
                next if ( $disk !~ m/$input_search/xms );
     
                $record{$time}{$type}{$disk}{name}      = $disk; 
                $record{$time}{$type}{$disk}{r_total}   = $r_total; 
                $record{$time}{$type}{$disk}{r_merged}  = $r_merged; 
                $record{$time}{$type}{$disk}{r_sectors} = $r_sectors; 
                $record{$time}{$type}{$disk}{r_ms}      = $r_ms; 
                $record{$time}{$type}{$disk}{w_total}   = $w_total; 
                $record{$time}{$type}{$disk}{w_merged}  = $w_merged; 
                $record{$time}{$type}{$disk}{w_sectors} = $w_sectors; 
                $record{$time}{$type}{$disk}{w_ms}      = $w_ms; 
                $record{$time}{$type}{$disk}{io_cur}    = $io_cur; 
                $record{$time}{$type}{$disk}{io_sec}    = $io_sec; 
    
                $counter += 1;
                $line_num{disk}++;
            }
        }
    
        
        ###
        ### Stats
        ###
        if ( $input_type =~ m/STATS/i ) {
    
            my $type = $vmstat_type{stat};
    
            if ( my ($value, $stat) = $line =~ m/^\s* (\d+)\s+ ([\D\s]+$) /xms ) {
    
                next if ( $stat !~ m/$input_search/xms );
    
                $record{$time}{$type}{$stat} = $value;
                $counter += 1;
            }
        }
    
    
        ###
        ### Slab
        ###
        if ( $input_type =~ m/SLAB/i ) {
            my $type=$vmstat_type{slab};
            if ( my ($cache,       $cache_num, 
                     $cache_total, $cache_size, $cache_pages) = $line =~ m/^\s*
                                                                           (\w+)\s+ (\d+)\s+ (\d+)\s+ 
                                                                           (\d+)\s+ (\d+)
                                                                           \s*$
                                                                          /xms ) {
    
                next if ( $cache !~ m/$input_search/xms );
                
                $record{$time}{$type}{$cache}{num}   = $cache_num;
                $record{$time}{$type}{$cache}{total} = $cache_total;
                $record{$time}{$type}{$cache}{size}  = $cache_size;
                $record{$time}{$type}{$cache}{pages} = $cache_pages;
    
                $counter += 1;
            }
        } 
    
    }
    close $INPUT_FILE;
    
    
    
    if ( $input_type =~ m/(?:DEFAULT|CPU)/i ) {
    
        $counter = 0;
        my $j = $vmstat_type{cpu};
    
        TIME: for my $i ( sort keys %record ) {
            print_headers($j, $counter, $format_cpu);
            printf "$format_cpu", $i, $record{$i}{$j}{r}, $record{$i}{$j}{b}, $record{$i}{$j}{us}, $record{$i}{$j}{sy}, $record{$i}{$j}{id}, $record{$i}{$j}{wa};
            $counter++;
        }
    }
    
    
    if ( $input_type =~ m/MEMORY/i ) {
    
        $counter = 0;
        my $j = $vmstat_type{memory};
    
        TIME: for my $i ( sort keys %record ) {
            print_headers($j, $counter, $format_mem);
            printf "$format_mem", $i, $record{$i}{$j}{swpd}, $record{$i}{$j}{free}, $record{$i}{$j}{buff}, $record{$i}{$j}{cache}, 
                                      $record{$i}{$j}{si},   $record{$i}{$j}{so},   $record{$i}{$j}{bi},   $record{$i}{$j}{bo}, 
                                      $record{$i}{$j}{in},   $record{$i}{$j}{cs};
            $counter++;
        }
    }
    
    
    my $prev_i;
    if ( $input_type =~ m/DISK/i ) {
    
        $counter = 0;
        my $j = $vmstat_type{disk};
    
        TIME: for my $i ( sort keys %record ) {
            STAT: for my $k ( sort keys %{ $record{$i}{$j} } ) {
                if ( $show_all_values ) {
    
                    print_headers($j, $counter, $format_disk);
                    printf "$format_disk", $i, $record{$i}{$j}{$k}{name}, $record{$i}{$j}{$k}{r_total}, $record{$i}{$j}{$k}{r_merged}, $record{$i}{$j}{$k}{r_sectors},
                                           $record{$i}{$j}{$k}{r_ms}, $record{$i}{$j}{$k}{w_total}, $record{$i}{$j}{$k}{w_merged}, $record{$i}{$j}{$k}{w_sectors},
                                           $record{$i}{$j}{$k}{w_ms}, $record{$i}{$j}{$k}{io_cur}, $record{$i}{$j}{$k}{io_sec};
    
                } else {
    
                    if ( ! defined $prev_i ) {
                        $prev_i = $i;
                        next TIME;
                    }

                    next    if ( $record{$i}{$j}{$k}{r_total} - $record{$prev_i}{$j}{$k}{r_total}     < $input_limit  &&
                                 $record{$i}{$j}{$k}{r_merged} - $record{$prev_i}{$j}{$k}{r_merged}   < $input_limit && 
                                 $record{$i}{$j}{$k}{r_sectors} - $record{$prev_i}{$j}{$k}{r_sectors} < $input_limit &&
                                 $record{$i}{$j}{$k}{r_ms} - $record{$prev_i}{$j}{$k}{r_ms}           < $input_limit && 
                                 $record{$i}{$j}{$k}{w_total} - $record{$prev_i}{$j}{$k}{w_total}     < $input_limit && 
                                 $record{$i}{$j}{$k}{w_merged} - $record{$prev_i}{$j}{$k}{w_merged}   < $input_limit && 
                                 $record{$i}{$j}{$k}{w_sectors} - $record{$prev_i}{$j}{$k}{w_sectors} < $input_limit ) ;

                    print_headers($j, $counter, $format_disk);
                    printf "$format_disk", $i, $record{$i}{$j}{$k}{name}, $record{$i}{$j}{$k}{r_total} - $record{$prev_i}{$j}{$k}{r_total}, 
                                                                          $record{$i}{$j}{$k}{r_merged} - $record{$prev_i}{$j}{$k}{r_merged}, 
                                                                          $record{$i}{$j}{$k}{r_sectors} - $record{$prev_i}{$j}{$k}{r_sectors},
                                                                          $record{$i}{$j}{$k}{r_ms} - $record{$prev_i}{$j}{$k}{r_ms}, 
                                                                          $record{$i}{$j}{$k}{w_total} - $record{$prev_i}{$j}{$k}{w_total}, 
                                                                          $record{$i}{$j}{$k}{w_merged} - $record{$prev_i}{$j}{$k}{w_merged}, 
                                                                          $record{$i}{$j}{$k}{w_sectors} - $record{$prev_i}{$j}{$k}{w_sectors},
                                                                          $record{$i}{$j}{$k}{w_ms} - $record{$prev_i}{$j}{$k}{w_ms}, 
                                                                          $record{$i}{$j}{$k}{io_cur}, $record{$i}{$j}{$k}{io_sec};
    
                }
                $counter++;
            }
            $prev_i = $i;
        }
    }
    
    undef $prev_i;
    if ( $input_type =~ m/STATS/i ) {
    
        $counter = 0;
        my $j = $vmstat_type{stat};
    
        TIME: for my $i ( sort keys %record ) {
            STAT: for my $k ( sort keys %{ $record{$i}{$j} } ) {
                if ( $show_all_values ) {
    
                    print_headers($j, $counter, $format_stats);
                    printf "$format_stats", $i, $k, $record{$i}{$j}{$k} ;
    
                } else {
    
                    if ( ! defined $prev_i ) {
                        $prev_i = $i;
                        next TIME;
                    }
                    print_headers($j, $counter, $format_stats);
                    printf "$format_stats", $i, $k, $record{$i}{$j}{$k} - $record{$prev_i}{$j}{$k} ;
    
                }
                $counter++;
            }
            $prev_i = $i;
        }
    }
    
    
    undef $prev_i;
    if ( $input_type =~ m/SLAB/i ) {
    
        $counter = 0;
        my $j = $vmstat_type{slab};
    
        TIME: for my $i ( sort keys %record ) {
            STAT: for my $k ( sort keys %{ $record{$i}{$j} } ) {
                if ( $show_all_values ) {
                    print_headers($j, $counter, $format_slab);
                    printf "$format_slab", $i, $k, $record{$i}{$j}{$k}{num}, $record{$i}{$j}{$k}{total}, $record{$i}{$j}{$k}{size}, $record{$i}{$j}{$k}{pages};
                } else {
                    if ( ! defined $prev_i ) {
                        $prev_i = $i;
                        next TIME;
                    }
                    print_headers($j, $counter, $format_slab);
                    printf "$format_slab", $i, $k, $record{$i}{$j}{$k}{num} - $record{$prev_i}{$j}{$k}{num}, 
                                                   $record{$i}{$j}{$k}{total} - $record{$prev_i}{$j}{$k}{total}, 
                                                   $record{$i}{$j}{$k}{size} - $record{$prev_i}{$j}{$k}{size}, 
                                                   $record{$i}{$j}{$k}{pages} - $record{$prev_i}{$j}{$k}{pages};
    
                }
                $counter++;
            }
            $prev_i = $i;
        }
    }
    
    print "\n";    
    exit;

}
 

    
   
sub parse_iostat {

    my ($input_file, $input_time, $input_search, $input_type, $input_limit, $show_all_values, $input_skip, $await_limit, $svctime_limit, $util_limit, $rd_limit, $wrt_limit ) = @_;
 
    my $format       = "%-18s %-11s %-20s %-11s %-11s %-11s %-11s %-11s %-11s %-11s %-11s %-11s \n";
    my $counter      = 0;
    my $trans_number = 0;
    my $time;
    my %record;
    my %asm_disk;
    my %cell_disk;
    my $is_asm_valid;
    my $is_exa_valid;
    my $std_out;
    my $std_out_02;
    my $cmd;
    my $count;
    my $oracleasm_cmd = "/usr/sbin/oracleasm";
    my $cellcli_cmd   = "cellcli";
 
    $await_limit   = 0    if !$await_limit;
    $svctime_limit = 0    if !$svctime_limit;
    $util_limit    = 0    if !$util_limit;
    $rd_limit      = 0    if !$rd_limit;
    $wrt_limit     = 0    if !$wrt_limit;
    $input_skip    = -1   if !$input_skip;

 
    ## Get info from file
    ## then print 
    ##
    open my $INPUT_FILE, '<', $input_file or croak "Can't open file: $input_file\n";
   
    if ( system("ls $oracleasm_cmd > /dev/null 2>&1 ") )  { $is_asm_valid = 0; } 
    else                                                  { $is_asm_valid = 1; }

    if ( system("which $cellcli_cmd > /dev/null 2>&1 ") )  { $is_exa_valid = 0; }
    else                                                   { $is_exa_valid = 1; }


    $count = 0;
    while (my $line = <$INPUT_FILE>) {
        chomp $line;
    
        if ($line =~ m{^zzz.*$}mx) {                              ## zzz signifies the start of a new transaction in the log file
            $trans_number += 1;
            #($time) =  $line =~ m{(\d{2}:\d{2}:\d{2})}xms;
            ($time) =  $line =~ m{(\w+\s+\d+\s+\d{2}:\d{2}:\d{2})}xms;
            $counter = 0;
            next;
        }
    
        if ( $line =~ m/avg-cpu/ ) {
            $counter++;
        }
    
        next if ( !defined $time );
        next if ( $time !~ m/$input_time/xms );
    
   
 
        #printf "%s\n",  "$line";

        if ( my ($device,    $rrqm_s,   $wrqm_s,   $r_s, 
                 $w_s,       $rsec_s,   $wsec_s,   $avgrq_sz, 
                 $avgqu_sz,  $await,    $svctm,    $util) = $line =~ m/^([\S]+)\s+
                                                                        ([\d\.]+)\s+
                                                                        ([\d\.]+)\s+
                                                                        ([\d\.]+)\s+
                                                                        ([\d\.]+)\s+
                                                                        ([\d\.]+)\s+
                                                                        ([\d\.]+)\s+
                                                                        ([\d\.]+)\s+
                                                                        ([\d\.]+)\s+
                                                                        ([\d\.]+)\s+
                                                                        ([\d\.]+)\s+
                                                                        ([\d\.]+)
                                                                      /xms )  {
    
        next if  ( $util < $util_limit );
        next if  ( $await < $await_limit );
        next if  ( $svctm < $svctime_limit );
        next if  ( $r_s < $rd_limit );
        next if  ( $w_s < $wrt_limit );
   
        $count++;
        next if  ( $count%$input_skip != 0 );
 
        next  if ( $rrqm_s   < $input_limit  && $wrqm_s   < $input_limit  && $r_s    < $input_limit && 
                   $w_s      < $input_limit  && $rsec_s   < $input_limit  && $wsec_s < $input_limit && 
                   $avgrq_sz < $input_limit  && $avgqu_sz < $input_limit  && $await  < $input_limit && 
                   $svctm    < $input_limit  && $util     < $input_limit );
    

        if ( $is_asm_valid && ! defined $asm_disk{$device} ) {
            $cmd="sudo $oracleasm_cmd querydisk /dev/$device" . "1 2>\&1" ;
            $std_out = `$cmd `;
            #printf "%s\n", "$cmd :  $std_out";

            $cmd="/oracledba/temp/tongelidis/orautil/io_map.sh -d /dev/$device -s" ;
            $std_out_02 = `$cmd `;
            if ( my ( $disk_name ) = $std_out =~ m/is\smarked\san\sASM\sdisk\swith\sthe\slabel.*"([\S]+)"$/xms ) {
                #printf "%s\n", "$device : $disk_name";
                $asm_disk{$device}  = $disk_name ;
            } elsif (  length $std_out_02 > 0 ) {
                chomp $std_out_02 ;
                $asm_disk{$device}  = $std_out_02 ;
            } else {
                $asm_disk{$device}  = ' ' ;
            }
        }

        if ( $is_exa_valid && ! defined $cell_disk{$device} ) {
            $cmd="sudo $oracleasm_cmd querydisk /dev/$device" . "1 2>\&1" ;
            $std_out = `$cmd `;
            #printf "%s\n", "$cmd :  $std_out";

            $cmd="/oracledba/temp/tongelidis/orautil/io_map.sh -d /dev/$device -s" ;
            $std_out_02 = `$cmd `;
            if ( my ( $disk_name ) = $std_out =~ m/is\smarked\san\sASM\sdisk\swith\sthe\slabel.*"([\S]+)"$/xms ) {
                #printf "%s\n", "$device : $disk_name";
                $asm_disk{$device}  = $disk_name ;
            } elsif (  length $std_out_02 > 0 ) {
                chomp $std_out_02 ;
                $asm_disk{$device}  = $std_out_02 ;
            } else {
                $asm_disk{$device}  = ' ' ;
            }
        }



        #printf "%s\n", "$asm_disk{$device}, $device  :  $input_search";
        next if  ( $asm_disk{$device} !~ /$input_search/  && $device !~ /$input_search/ );
 
        $record{$time}{"$device.$counter"}{asm_disk} = $asm_disk{$device};
        $record{$time}{"$device.$counter"}{rrqm_s}   = $rrqm_s;
        $record{$time}{"$device.$counter"}{wrqm_s}   = $wrqm_s;
        $record{$time}{"$device.$counter"}{r_s}      = $r_s;
        $record{$time}{"$device.$counter"}{w_s}      = $w_s;
        $record{$time}{"$device.$counter"}{rsec_s}   = $rsec_s;
        $record{$time}{"$device.$counter"}{wsec_s}   = $wsec_s;
        $record{$time}{"$device.$counter"}{avgrq_sz} = $avgrq_sz;
        $record{$time}{"$device.$counter"}{avgqu_sz} = $avgqu_sz;
        $record{$time}{"$device.$counter"}{await}    = $await;
        $record{$time}{"$device.$counter"}{svctm}    = $svctm;
        $record{$time}{"$device.$counter"}{util}     = $util;
    
        #printf "$format", $time, "$device.$counter" , $rrqm_s, $wrqm_s, $r_s, $w_s, $rsec_s, $wsec_s, $avgrq_sz, $avgqu_sz, $await, $svctm, $util;
        $counter++;
        } 
    }
    
    close $INPUT_FILE;
    
    
    $counter = 0;
    for my $i ( sort keys %record ) {
    
        for my $j ( sort keys %{ $record{$i} } ) {
            my ($device, $snapshot) = $j =~ m/(\S+)\.(\d+)/ ;
            #next if ( $snapshot == 1 ) ;
    
            print_headers($input_osw, $counter, $format);
            printf "$format", $i, $device, 
                                       $record{$i}{$j}{asm_disk}, 
                                       #$record{$i}{$j}{rrqm_s}, 
                                       #$record{$i}{$j}{wrqm_s}, 
                                       $record{$i}{$j}{r_s}, 
                                       $record{$i}{$j}{w_s}, 
                                       $record{$i}{$j}{rsec_s}, 
                                       $record{$i}{$j}{wsec_s}, 
                                       $record{$i}{$j}{avgrq_sz}, 
                                       $record{$i}{$j}{avgqu_sz}, 
                                       $record{$i}{$j}{await}, 
                                       $record{$i}{$j}{svctm}, 
                                       $record{$i}{$j}{util}; 
        $counter++;
        }
    }
    
    print "\n";    
    exit;
   
}    
    
   

sub parse_mpstat {

    my ($input_file, $input_time, $input_search, $input_type, $input_limit, $show_all_values, $input_skip ) = @_;

    my $format       = "%-18s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s \n";
    my $counter      = 0;
    my $trans_number = 0;
    my $time;

    open my $INPUT_FILE, '<', $input_file or croak "Can't open file: $input_file\n";
    
    while (my $line = <$INPUT_FILE>) {
        chomp $line;
    
        if ($line =~ m{^zzz.*$}mx) {                              ## zzz signifies the start of a new transaction in the log file
            $trans_number += 1;
            #($time) =  $line =~ m{(\d{2}:\d{2}:\d{2})}xms;
            ($time) =  $line =~ m{(\w+\s+\d+\s+\d{2}:\d{2}:\d{2})}xms;
            next;
        }
    
        next if ( !defined $time );
        next if ( $time !~ m/$input_time/xms );
     
    
##      10:06:46      11  100.00    0.00    0.00    0.00    0.00    0.00    0.00    0.00     18.00

        #if ( my ($time1, $time2, $type,   $user, 
        if ( my ($time1, $type,   $user, 
                 $nice,  $sys,   $iowait, $irq, 
                 $soft,  $steal, $idle,   $intr) = $line =~ m/^(\d+:\d+:\d+\s*?\w*?)\s+
                                                               (\w+)\s+
                                                               ([\d\.]+)\s+
                                                               ([\d\.]+)\s+
                                                               ([\d\.]+)\s+
                                                               ([\d\.]+)\s+
                                                               ([\d\.]+)\s+
                                                               ([\d\.]+)\s+
                                                               ([\d\.]+)\s+
                                                               ([\d\.]+)\s+
                                                               ([\d\.]+)
                                                             /xms ) {;
    
        next if ( $type !~ m/$input_search/ );

        print_headers($input_osw, $counter, $format);

        printf "$format", $time, $type, $user, $nice, $sys, $iowait, $irq, $soft, $steal, $idle, $intr;
        $counter++;
    
        } 
    }
    
    close $INPUT_FILE;
}


sub parse_netstat {

    my ($input_file, $input_time, $input_search, $input_type, $input_limit, $show_all_values, $input_skip ) = @_;

    open my $INPUT_FILE, '<', $input_file or croak "Can't open file: $input_file\n";
    
    my $line_number = 0;
    my $trans_number = 0;
    my $time;
    my @records;
    my $counter=0;
    my @time;
    my $format="%-18s %-60s %-20s %-20s %-20s ";
    my $printed_header;
    my $stat_type;
    
    
    while (my $line = <$INPUT_FILE>) {
        chomp $line;
        $line_number += 1;
    
        if ( $line =~ m/Linux/) { next };
    
        if ($line =~ m{^zzz.*$}mx) {                              ## zzz signifies the start of a new transaction in the log file
            $trans_number++;
            #($time) =  $line =~ m{(\d{2}:\d{2}:\d{2})}xms;
            ($time) =  $line =~ m{(\w+\s+\d+\s+\d{2}:\d{2}:\d{2})}xms;
            $counter ++ if ( $time =~ m/$input_time/xms ) ;
            next;
            
        }
    
        next if ( !defined $time );
        next if ( $time !~ m/$input_time/xms ) ;
        next if ( $line =~ m/- no statistics available -/ );
    
        if (my ($interface, $mtu,    $met,    $rx_ok,
                $rx_err,    $rx_drp, $rx_ovr, $tx_ok,
                $tx_err,    $tx_drp, $tx_ovr ) = $line =~ m/^\s*
                                                            (\w+)\s+
                                                            (\d+)\s+
                                                            (\d+)\s+
                                                            (\d+)\s+
                                                            (\d+)\s+
                                                            (\d+)\s+
                                                            (\d+)\s+
                                                            (\d+)\s+
                                                            (\d+)\s+
                                                            (\d+)\s+
                                                            (\d+)\s+
                                                           /xms ) {
    
            if ( ! defined $time[$counter] ) {
                $time[$counter]=$time;
            }
     
            $records[$counter]{"$interface: MTU"}=$mtu;
            $records[$counter]{"$interface: MTU"}=$mtu;
            $records[$counter]{"$interface: MET"}=$met;
            $records[$counter]{"$interface: RX_OK"}=$rx_ok;
            $records[$counter]{"$interface: TX_OK"}=$tx_ok;
            $records[$counter]{"$interface: RX_ERR"}=$rx_err;
            $records[$counter]{"$interface: TX_ERR"}=$tx_err;
            $records[$counter]{"$interface: RX_DRP"}=$rx_drp;
            $records[$counter]{"$interface: TX_DRP"}=$tx_drp;
            $records[$counter]{"$interface: RX_OVR"}=$rx_ovr;
            $records[$counter]{"$interface: TX_OVR"}=$tx_ovr;
    
            next ;
        }
    
        if ( my ($value, $stat_name) = $line =~ m/^\s*(\d+)\s+(.*)/xms ) {
    
            if ( ! defined $time[$counter] ) { 
                $time[$counter]=$time;
            }
    
            $records[$counter]{$stat_type . ': ' . $stat_name}=$value;
            next ;
        }
    
        if (my ($stat_name, $value) = $line =~ m/^\s*(.*)\s+(\d+)/xms ) {
    
            if ( ! defined $time[$counter] ) {
                $time[$counter]=$time;
            }
    
            $stat_name =~ s/://g;
            $records[$counter]{$stat_type . ': ' . $stat_name}=$value;
            next ;
        }
    
        if ( my ( $stat_found ) = $line =~ m/^(\w+):$/xms ) {
            $stat_type = $stat_found;
            next;
        } }
    
    close $INPUT_FILE;
    
    
    RECORDS: for ( my $i=2; $i< scalar(@records); $i++) {
        my $printed_header=0;
    
        STATS: for my $k ( sort { ($records[$i]{$a}-$records[$i-1]{$a}) <=> ($records[$i]{$b}-$records[$i-1]{$b})  }  keys %{ $records[$i] } ) {
            next RECORDS if ( ! defined $records[$i-1] );
    
            if ( $k =~ m/$input_search/i ) {
                my $delta =  $records[$i]{$k} -  $records[$i-1]{$k};
                if ( $delta != 0 ) {
                    if ( $printed_header==0 ) {
                        print_headers($input_osw, $page_size, $format);
                        $printed_header = 1;
 
                    }
            
    
                    printf "$format\n", $time[$i], $k, $delta, $records[$i-1]{$k}, $records[$i]{$k};
                } 
            } 
        } 
    }
}
    
    

sub parse_tracert {

    my ($input_file, $input_time, $input_search, $input_type, $input_limit, $show_all_values, $input_skip ) = @_;
    open my $INPUT_FILE, '<', $input_file or croak "Can't open file: $input_file\n";
    
    my $trans_number = 0;
    my $time;
    my @traces;
    my $format="%-18s %-10s %-40s %-12s %-12s %-12s";
    my $counter = 0;
    
    
    while (my $line = <$INPUT_FILE>) {
        chomp $line;
        my %record;
    
        if ( $line =~ m/Linux/) { next };
    
        if ($line =~ m{^zzz.*$}mx) {                              ## zzz signifies the start of a new transaction in the log file
            $trans_number++;
            #($time) =  $line =~ m{(\d{2}:\d{2}:\d{2})}xms;
            ($time) =  $line =~ m{(\w+\s+\d+\s+\d{2}:\d{2}:\d{2})}xms;
            next;
        }
    
        next    if ( ! defined $time ) ;
        next    if ( $time !~ m/$input_time/xms ) ;
     
        if ( my ($attempt, $hostname, $ip, $trip_1, 
                 $unit_1,  $trip_2,   $trip_3) = $line =~ m/^\s*
                                                            (\d+)\s+
                                                            (?:\*\s)?
                                                            (?:\*\s)?
                                                            ([\w\-\.]+)\s+
                                                            ([\d\.\(\)]*)\s+
                                                            ([\-\d\.]+)\s+
                                                            (\w+\s+)?
                                                            (?:\!H\s+)?
                                                            ([\-\*\d\.]*\s+)?
                                                            (?:\w+\s+)?
                                                            (?:\!H\s)?
                                                            ([\-\*\d\.]*)?
                                                           /xms ) {
    
            $hostname =~ s/\..*\.navteq\.com//;
            next if ( $hostname !~ /$input_search/i );
   
            $trip_3 = '*' if (! defined $trip_3); 
            $trip_2 = '*' if (! defined $trip_2); 

            print_headers($input_osw, $counter, $format);
            printf "$format\n", $time, $attempt, "$hostname: $ip",
                                $trip_1, $trip_2, $trip_3;
    
            $counter++;
            next ;
        }
     
       
#        if ( my ($attempt, $trip_1, 
#                 $trip_2,  $trip_3) = $line =~ m/^\s*
#                                                 (\d+)\s+
#                                                 (.*?)\s+
#                                                 (.*?)\s+
#                                                 (.*?)
#                                                /xms ) {
#    
#            print_headers($input_osw, $counter, $format);
#            printf "$format\n", $time, $attempt, "*",
#                               $trip_1, $trip_2, $trip_3;
#   
#            $counter++;
#            next ;
#    
#        }
    }
    close $INPUT_FILE;
}


sub parse_top {

    my ($input_file, $input_time, $input_search, $input_type, $input_limit, $show_all_values, $input_skip, $active, $list ) = @_;
    open my $INPUT_FILE, '<', $input_file or croak "Can't open file: $input_file\n";


    my $limit     = $input_limit;
    $limit        = .001  if (  defined $active);
    my $line_number = 0;
    my $LINE_HAS_PROCESS_DATA=0;
    my %process_record;
    my $time;
    my %summary;
    my $counter;
 
    
    ## Print some intro info
    ##
    print "Searching for active processes: CPU or Memory > $limit\n";
    print "Searching for user/process: $input_search\n";
    print "Searching for time: $input_time\n";
    
    while (my $line = <$INPUT_FILE>) {
        chomp $line;
        $line_number += 1;
    
        if ($line =~ m{^zzz.*$}mx) {                              ## zzz signifies the start of a new transaction in the log file
            $LINE_HAS_PROCESS_DATA=0;
            #($time) =  $line =~ m{(\d{2}:\d{2}:\d{2})}xms;
            ($time) =  $line =~ m{(\w+\s+\d+\s+\d{2}:\d{2}:\d{2})}xms;
            next;
        }
    
        next  if ( !defined $time );
        next  if ( $time !~ m/$input_time/xms );
    
     
        if ( $line =~ m/^(top.*)$/xms ) {
            $summary{$time}{load} = $1;
            next;
        }
    
        if ($line =~ m/^(Tasks.*)$/xms) {
            $summary{$time}{tasks} = $1;
            next;
        }
    
        if ($line =~ m/^(Mem.*)$/xms) {
            $summary{$time}{mem} = $1;
            next;
        }
    
        if ($line =~ m/^(Swap.*)$/xms) {
            $summary{$time}{swap} = $1;
            next;
        }
    
        if ($line =~ m/^(Cpu.*)$/xms) {
            $summary{$time}{cpu} = $1;
            next;
        }
    
    
        if ($line =~ m/^\s*PID/xms) {                             ## PID signifies the start of process information
            $LINE_HAS_PROCESS_DATA=1;
            next;
        }
    
        if (! $LINE_HAS_PROCESS_DATA || $line =~ m/^\s*$/xms) {   ## if the line doesn't have process info or is blank
            next;
        }
        else {
            my ($pid, $user, $pr, $ni, $virt, $res, $shr, $status, $cpu, $mem, $cpu_time, $cmd) = split " ", $line, 12;
    
    
            if ( ($user =~ m/$input_search/xms || "$pid,$cmd" =~m/$input_search/xms) && $time =~ m/$input_time/ && ($cpu >= $limit || $mem >= $limit) )  {
    
                $process_record{$time}{"$pid,$cmd"} = {
                                                   pid      => $pid,
                                                   user     => $user,
                                                   pr       => $pr,
                                                   ni       => $ni,
                                                   virt     => $virt,
                                                   res      => $res,
                                                   shr      => $shr,
                                                   status   => $status,
                                                   cpu      => $cpu,
                                                   mem      => $mem,
                                                   time     => $cpu_time,
                                                   cmd      => $cmd,
                                               };
                                                   
                #print "TIME: $time  PROCESS_ID: $pid USER=$user CMD=$cmd\n";
            }
        }
    
    }
    close $INPUT_FILE;
    
    
    
    my %result_set;
    $counter = 0;
    my $format = "%-18s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-20s\n"; 
    
    for my $time (sort keys %process_record) {
    
        if ( !$list ) {
            print "\n$summary{$time}{load}\n" if ( defined $summary{$time}{load} ) ;
            print "$summary{$time}{tasks}\n"  if ( defined $summary{$time}{tasks} ) ;
            print "$summary{$time}{cpu}\n"    if ( defined $summary{$time}{cpu} ) ;
            print "$summary{$time}{mem}\n"    if ( defined $summary{$time}{mem} ) ;
            print "$summary{$time}{swap}\n"   if ( defined $summary{$time}{swap} ) ;
            print_headers($input_osw, $page_size, $format);
        }
    
        for my $pid (sort keys %{ $process_record{$time} }) {
            
            if ( ! defined $process_record{$time}{$pid}{pid} ) {
                print "\n******* No Data **********\n";
                next;
            }
    
            if ( $list ) {
                print "$process_record{$time}{$pid}{pid}\n";
                next;
            }
    
            printf "$format", "$time",
                              "$process_record{$time}{$pid}{pid}",
                              "$process_record{$time}{$pid}{user}",
                              "$process_record{$time}{$pid}{pr}",
                              "$process_record{$time}{$pid}{ni}",
                              "$process_record{$time}{$pid}{status}",
                              "$process_record{$time}{$pid}{mem}",
                              "$process_record{$time}{$pid}{cpu}",
                              "$process_record{$time}{$pid}{time}",
                              "$process_record{$time}{$pid}{cmd}";
            $counter += 1 ;
            $result_set{$process_record{$time}{$pid}{pid}}++;
        }
    
    if ( !$list ) {
        printf "Number of Processes:    %9i\n", $counter ;
    }
    
    $counter = 0;
    
    }
}



sub parse_slabinfo {

    my ($input_file, $input_time, $input_search, $input_type, $input_limit, $show_all_values, $input_skip ) = @_;
    open my $INPUT_FILE, '<', $input_file or croak "Can't open file: $input_file\n";
    
    my $line_number  = 0;
    my $trans_number = 0;
    my $counter      = 0;
    my $time;
    my @records;
    my @time;
    my $format="%-18s %-60s %-20s %-20s %-20s \n";
    my $printed_header;
    my $stat_type;
    
    
    while (my $line = <$INPUT_FILE>) {
        chomp $line;
        $line_number += 1;
    
        if ( $line =~ m/Linux/) { next };
    
        if ($line =~ m{^zzz.*$}mx) {                              ## zzz signifies the start of a new transaction in the log file
            $trans_number++;
            #($time) =  $line =~ m{(\d{2}:\d{2}:\d{2})}xms;
            ($time) =  $line =~ m{(\w+\s+\d+\s+\d{2}:\d{2}:\d{2})}xms;
            $counter ++ if ( $time =~ m/$input_time/xms ) ;
            next;
            
        }
    
        next if ( !defined $time );
        next if ( $time !~ m/$input_time/xms ) ;
    
        if (my ($stat_name,     $active_objs,  $num_objs,   
                $objsize,       $objperslab,   $pagesperslab, 
                $limit,         $batchcount,   $sharedfactor,  
                $active_slabs,  $num_slabs,    $sharedavail ) = $line =~ m/^\s*
                                                                           (\w+)\s+
                                                                           (\d+)\s+
                                                                           (\d+)\s+
                                                                           (\d+)\s+
                                                                           (\d+)\s+
                                                                           (\d+)\s+
                                                                           :\s+tunables\s+
                                                                           (\d+)\s+
                                                                           (\d+)\s+
                                                                           (\d+)\s+
                                                                           :\s+slabdata\s+
                                                                           (\d+)\s+
                                                                           (\d+)\s+
                                                                           (\d+)
                                                                          /xms ) {
    
            if ( !defined $time[$counter] ) {
                $time[$counter]=$time;
            }
     
            $records[$counter]{"$stat_name: active_objs"}  = $active_objs;
            $records[$counter]{"$stat_name: num_objs"}     = $num_objs;
            $records[$counter]{"$stat_name: objsize"}      = $objsize;
            $records[$counter]{"$stat_name: pagesperslab"} = $pagesperslab;
            $records[$counter]{"$stat_name: limit"}        = $limit;
            $records[$counter]{"$stat_name: batchcount"}   = $batchcount;
            $records[$counter]{"$stat_name: sharedfactor"} = $sharedfactor;
            $records[$counter]{"$stat_name: active_slabs"} = $active_slabs;
            $records[$counter]{"$stat_name: num_slabs"}    = $num_slabs;
            $records[$counter]{"$stat_name: sharedavail"}  = $sharedavail;
    
            next ;
        } }
    
    close $INPUT_FILE;



    $counter=0;
    RECORDS: for ( my $i=2; $i< scalar(@records); $i++) {
    
        if ( ! defined $records[$i-1] ) { next RECORDS };
    
        STAT_VALUES: for my $k ( sort { ($records[$i]{$a}-$records[$i-1]{$a}) <=> ($records[$i]{$b}-$records[$i-1]{$b})  }  keys %{ $records[$i] } ) {
    
           if ( $k =~ m/$input_search/ ) {
    
                my $delta =  $records[$i]{$k} -  $records[$i-1]{$k};
                if ( $delta != 0 ) {
                    print_headers($input_osw, $counter, $format);
                    printf "$format", $time[$i], $k, $delta, $records[$i-1]{$k}, $records[$i]{$k};
                    $counter++;
                } 
            } 
        } 
    }

}



sub parse_ps {

    my ($input_file, $input_time, $input_search, $input_type, $input_limit, $show_all_values, $input_skip, $input_pid, $input_state, $input_mem, $input_cpu ) = @_;
    open my $INPUT_FILE, '<', $input_file or croak "Can't open file: $input_file\n";


    my $format       = "%-18s %-5s %-5s %-8s %-8s %-8s %-5s %-5s %-5s %-5s %-8s %-8s %-8s %-8s  %-20s \n";
    my $format2      = "%-117s  %-20s \n";
    my $counter      = 0;
    my $process_cnt  = 0;
    my $process_cnt_tm;
    my $trans_number = 0;
    my $time;
    my $prev_time;
    my $cmd_length; 
    my $cmd_counter;
    my $cmd_char     = 90;

    $input_pid = '.*'                               if (! defined $input_pid) ;   
    $input_state = '.*'                             if (! defined $input_state) ;   
    $input_mem = 0                                  if (! defined $input_mem) ;   
    $input_cpu = 0                                  if (! defined $input_cpu) ;   
    
    
    while (my $line = <$INPUT_FILE>) {
        chomp $line;
    
        if ($line =~ m{^zzz.*$}mx) {                              ## zzz signifies the start of a new transaction in the log file
            $trans_number += 1;
            #($time) =  $line =~ m{(\d{2}:\d{2}:\d{2})}xms;
            ($time) =  $line =~ m{(\w+\s+\d+\s+\d{2}:\d{2}:\d{2})}xms;
            next;
        }
    
        next if ( !defined $time );
        next if ( $time !~ m/$input_time/xms );
     
    
        if ( my ($flag,  $stat,      $uid,       $pid, 
                 $ppid,  $cpu_util,  $priority,  $nice, 
                 $addr,  $sz,        $wchan,     $stime,
                 $tty,   $ps_time,   $cmd               ) = $line =~ m/^(\d+)\s+
                                                                        (\w+)\s+
                                                                        (\w+)\s+
                                                                        (\d+)\s+
                                                                        (\d+)\s+
                                                                        (\d+)\s+
                                                                        ([-\w]+)\s+
                                                                        ([-\w]+)\s+
                                                                        ([-\w\?]+)\s+
                                                                        ([-\w]+)\s+
                                                                        ([-\w\?]+)\s+
                                                                        ([\w\d:]+\s?\d*)\s+
                                                                        ([\w\?]+)\s+
                                                                        ([\w\d:]+)\s+
                                                                        (.*)
                                                             /xms ) {;
    
        next  if ( $pid !~ m/$input_pid/ ) ;
        next  if ( $stat !~ m/$input_state/ ) ;
        next  if ( $sz  < $input_mem ) ;
        next  if ( $cpu_util < $input_cpu ) ;
        next  if ( "$cmd$pid" !~ m/$input_search/ ) ;
    
    
        print_headers($input_osw, $page_size, $format) if (! defined $prev_time) ;
        if ( defined $prev_time && $time ne $prev_time  ) {
            print "\n Processes matching $input_search at $prev_time: $process_cnt \n";
            print_headers($input_osw, $page_size, $format);
            $process_cnt = 0;
            $process_cnt_tm = $time;
            $prev_time = $time; 

        } else {
            $prev_time = $time;
        }

        $cmd_counter = 0;
        $cmd_length = length $cmd ;
        if ( $cmd_length < $cmd_char ) {
            printf "$format", $time, $flag,    $stat,      $uid,       $pid,
                                     $ppid,    $cpu_util,  $priority,  $nice,
                                     $addr,    $sz,        $wchan,     $stime,
                                     $ps_time, $cmd ; }
        else {
            while ( ($cmd_counter * $cmd_char) < $cmd_length ) {
                if ( $cmd_counter == 0 ) {
                    printf "$format", $time, $flag,    $stat,      $uid,       $pid,
                                             $ppid,    $cpu_util,  $priority,  $nice,
                                             $addr,    $sz,        $wchan,     $stime,
                                             $ps_time, substr($cmd, $cmd_counter*$cmd_char, $cmd_char) ; 
                } else {
                    printf "$format2", ' ', substr($cmd, $cmd_counter*$cmd_char, $cmd_char);
                }
                $cmd_counter++; 
            }    
        }
        


        $process_cnt++;
        $counter++;
        } 
    }
    print "\n Processes matching $input_search at $process_cnt_tm: $process_cnt \n" if ( defined $process_cnt_tm );
    
    close $INPUT_FILE;
}


sub parse_vxstat {

    my ($input_file, $input_time, $input_search, $input_type, $input_limit, $show_all_values, $input_skip, $input_pid ) = @_;

    $input_type='vol'                               if ( $input_type eq 'DEFAULT' );
    
    my $hdr_format       = "%-18s %-5s %-13s %-13s %-13s %-13s %-13s %-11s %-11s %-50s \n";
    my $col_format       = "%-18s %-11s %-11s %-+11d %-+11d %-+11d %-+11d %-11s %-11s %-50s \n";
    my $counter      = 0;
    my $trans_number = 0;
    my $time;
    my %record;
    
    ## Get info from file
    ## then print 
    ##
    open my $INPUT_FILE, '<', $input_file or croak "Can't open file: $input_file\n";
    
    while (my $line = <$INPUT_FILE>) {
        chomp $line;
    
        if ($line =~ m{^zzz.*$}mx) {                              ## zzz signifies the start of a new transaction in the log file
            $trans_number += 1;
            #($time) =  $line =~ m{(\d{2}:\d{2}:\d{2})}xms;
            ($time) =  $line =~ m{(\w+\s+\d+\s+\d{2}:\d{2}:\d{2})}xms;
            $counter = 0;
            next;
        }
    
        next if ( !defined $time );
        next if ( $time !~ m/$input_time/xms );
        next if ( $line =~ m/^\s*(OPERATIONS|TYP)/ ) ;
    
        if ( my $diskgroup = $line =~ m/^DG\s(\w+)/ ) {
            $counter++;
            next;
        }
                 
        if ( my ($type,         $name,         $read_ops,     $write_ops, 
                 $read_blks,    $write_blks,   $avg_rd_tm,    $avg_wrt_tm, 
                 $atm_cp_op,    $atm_cp_blks,  $atm_cp_avg,   $vfd_rd_ops,
                 $vfd_wrt_ops,  $vfd_rd_blks,  $vfd_wrt_blks, $vfd_rd_ms,
                 $vfd_wrt_ms,   $crt_rd,       $crt_wrt,      $fld_rd,
                 $fld_wrt,      $rwbk_ops,     $rwbk_blks,    $rwbk_avg,
                 $rds_snp_ops,  $rds_snp_blks, $rds_snp_avg,  $psh_wrt_ops,
                 $psh_wrt_blks, $psh_wrt_avg ) = $line =~ m/^(\w+)\s+     ([\w-]+)\s+     ([\d\.]+)\s+ ([\d\.]+)\s+
                                                             ([\d\.]+)\s+ ([\d\.]+)\s+ ([\d\.]+)\s+ ([\d\.]+)\s+
                                                             (?: ([\d\.]+)\s+ ([\d\.]+)\s+ ([\d\.]+)\s+ ([\d\.]+)\s+
                                                             ([\d\.]+)\s+ ([\d\.]+)\s+ ([\d\.]+)\s+ ([\d\.]+)\s+
                                                             ([\d\.]+)\s+ ([\d\.]+)\s+ ([\d\.]+)\s+ ([\d\.]+)\s+
                                                             ([\d\.]+)\s+ ([\d\.]+)\s+ ([\d\.]+)\s+ ([\d\.]+)\s+
                                                             ([\d\.]+)\s+ ([\d\.]+)\s+ ([\d\.]+)\s+ ([\d\.]+)\s+
                                                             ([\d\.]+)\s+ ([\d\.]+) )?
                                                           /xms ) {;
    
            next if  ( $name !~ /$input_search/ );
            next if  ( $type !~ /$input_type/ );
    
        
            $record{$time}{"$type:$name"}{type}                 = $type;
            $record{$time}{"$type:$name"}{name}                 = $name;
            $record{$time}{"$type:$name"}{read_ops}             = $read_ops;
            $record{$time}{"$type:$name"}{write_ops}            = $write_ops;
            $record{$time}{"$type:$name"}{read_blks}            = $read_blks;
            $record{$time}{"$type:$name"}{write_blks}           = $write_blks;
            $record{$time}{"$type:$name"}{avg_rd_tm}            = $avg_rd_tm;
            $record{$time}{"$type:$name"}{avg_wrt_tm}           = $avg_wrt_tm;
            $record{$time}{"$type:$name"}{atm_cp_op}            = $atm_cp_op;
            $record{$time}{"$type:$name"}{atm_cp_blks}          = $atm_cp_blks;
            $record{$time}{"$type:$name"}{atm_cp_avg}           = $atm_cp_avg;
            $record{$time}{"$type:$name"}{vfd_rd_ops}           = $vfd_rd_ops;
            $record{$time}{"$type:$name"}{vfd_wrt_ops}          = $vfd_wrt_ops;
            $record{$time}{"$type:$name"}{vfd_rd_blks}          = $vfd_rd_blks;
            $record{$time}{"$type:$name"}{vfd_wrt_blks}         = $vfd_wrt_blks;
            $record{$time}{"$type:$name"}{vfd_rd_ms}            = $vfd_rd_ms;
            $record{$time}{"$type:$name"}{vfd_wrt_ms}           = $vfd_wrt_ms;
            $record{$time}{"$type:$name"}{crt_rd}               = $crt_rd;
            $record{$time}{"$type:$name"}{crt_wrt}              = $crt_wrt;
            $record{$time}{"$type:$name"}{fld_rd}               = $fld_rd;
            $record{$time}{"$type:$name"}{fld_wrt}              = $fld_wrt;
            $record{$time}{"$type:$name"}{rwbk_ops}             = $rwbk_ops;
            $record{$time}{"$type:$name"}{rwbk_blks}            = $rwbk_blks;
            $record{$time}{"$type:$name"}{rwbk_avg}             = $rwbk_avg;
            $record{$time}{"$type:$name"}{rds_snp_ops}          = $rds_snp_ops;
            $record{$time}{"$type:$name"}{rds_snp_blks}         = $rds_snp_blks;
            $record{$time}{"$type:$name"}{rds_snp_avg}          = $rds_snp_avg;
            $record{$time}{"$type:$name"}{psh_wrt_ops}          = $psh_wrt_ops;
            $record{$time}{"$type:$name"}{psh_wrt_blks}         = $psh_wrt_blks;
            $record{$time}{"$type:$name"}{psh_wrt_avg}          = $psh_wrt_avg;
    
        }
    
    }
    
    close $INPUT_FILE;
    
    
    $counter = 0;
    my $previous_i;
    
    for my $i ( sort keys %record ) {
    
        for my $j ( sort keys %{ $record{$i} } ) {
            
            if ( $show_all_values )   {

                print_headers($input_osw, $counter, $hdr_format);

                printf "$hdr_format",     $i, 
                                      $record{$i}{$j}{type},    
                                      $record{$i}{$j}{name},    
                                      $record{$i}{$j}{read_ops},
                                      $record{$i}{$j}{write_ops},
                                      $record{$i}{$j}{read_blks},
                                      $record{$i}{$j}{write_blks},
                                      $record{$i}{$j}{avg_rd_tm}, 
                                      $record{$i}{$j}{avg_wrt_tm}, 
                                  ' ';
    
            }
            else {
    
                next if ( ! defined $previous_i ) ;
    
                next if ( $record{$i}{$j}{read_ops} - $record{$previous_i}{$j}{read_ops} < $input_limit  &&
                          $record{$i}{$j}{write_ops} - $record{$previous_i}{$j}{write_ops} < $input_limit &&
                          $record{$i}{$j}{read_blks} - $record{$previous_i}{$j}{read_blks} < $input_limit &&
                          $record{$i}{$j}{write_blks} - $record{$previous_i}{$j}{write_blks} < $input_limit ) ;
     
                print_headers($input_osw, $counter, $hdr_format);

                printf "$hdr_format",     $i, 
                                      $record{$i}{$j}{type}, 
                                      $record{$i}{$j}{name}, 
                                      $record{$i}{$j}{read_ops} -  ( defined $record{$previous_i}{$j}{read_ops}   ? $record{$previous_i}{$j}{read_ops}   : 0 ),
                                      $record{$i}{$j}{write_ops} - ( defined $record{$previous_i}{$j}{write_ops}  ? $record{$previous_i}{$j}{write_ops}  : 0 ),
                                      $record{$i}{$j}{read_blks} - ( defined $record{$previous_i}{$j}{read_blks}  ? $record{$previous_i}{$j}{read_blks}  : 0 ),
                                      $record{$i}{$j}{write_blks} -( defined $record{$previous_i}{$j}{write_blks} ? $record{$previous_i}{$j}{write_blks} : 0 ),

                                      #commify($record{$i}{$j}{read_ops} - $record{$previous_i}{$j}{read_ops}), 
                                      #commify($record{$i}{$j}{write_ops} - $record{$previous_i}{$j}{write_ops}), 
                                      #commify($record{$i}{$j}{read_blks} - $record{$previous_i}{$j}{read_blks}),
                                      #commify($record{$i}{$j}{write_blks} - $record{$previous_i}{$j}{write_blks}), 

                                      $record{$i}{$j}{avg_rd_tm}, 
                                      $record{$i}{$j}{avg_wrt_tm}, 
                                  ' ';
            }
            $counter++;
        }
        $previous_i=$i;
    }
}



sub format_number {
    my $number = shift;
    my $units  = shift;
    my $output;

    my $sign = qw( );
    $number =~ s/^(\-)?// ;
    $sign = $1 if ( defined $1 );


    if    ( length $number > 12 ) {
        $output = defined $sign ? $sign . int( $number/($units*$units*$units) ) . 'G'
                                : int( $number/($units*$units*$units) ) . 'G'  ;
    }
    elsif ( length $number > 6 ) {
        $output = defined $sign ? $sign . int( $number/($units*$units) ) . 'M'
                                : int( $number/($units*$units) ) . 'M';
    }
    elsif ( length $number > 3 ) {
        $output = defined $sign ? $sign . int( $number/($units) ) . 'K'
                                : int( $number/($units) ) . 'K';
    }
    else {
        $output = defined $sign ? $sign . int $number
                                : int $number ;
    }

    chomp $output;

    return commify($output);
}


sub commify {
    local $_ = shift;
    1 while s/^(-?\d+)(\d{3})/$1,$2/;
    return $_;
}



sub print_headers {

    my $data_type = shift @_;
    my $count     = shift @_;
    my $format    = shift @_;
    my @headers;

    if ( $count%$page_size == 0 ) {
        if ( $data_type =~ m/VMSTAT_CPU/i ) {
            printf "\n$format", "",     "Procs",    "Procs", "CPU",  "CPU",  "CPU", "CPU";
            printf "$format",   "Time", "RunQueue", "Sleep", "User", "Sys", "Idle", "Wait";
            printf "$format",   "----", "--------", "-----", "----", "---", "---",  "----";

        }
        elsif ( $data_type =~ m/VMSTAT_MEMORY/i ) {
            printf "\n$format", "",     "Mem",  "Mem",  "Mem",     "Mem",   "Swap", "Swap", "Blocks", "Blocks", "System",    "System"  ;
            printf "$format",   "Time", "Swap", "Free", "Buffers", "Cache", "In",   "Out",  "In",     "Out",    "Interupts", "Cont Swch";
            printf "$format",   "----", "----", "----", "-------", "-----", "--",   "---",  "--",     "---",    "---------", "---------";
        }
        elsif ( $data_type =~ m/VMSTAT_DISK/i ) {
            printf "\n$format", "",     "",     "Read",  "Read",   "Read",    "Read", "Write", "Write",  "Write",   "Write", "IO",  "IO" ;
            printf "$format",   "Time", "Disk", "Total", "Merged", "Sectors", "ms",   "Total", "Merged", "Sectors", "ms",    "Cur", "Sec";
            printf "$format",   "----", "----", "-----", "------", "-------", "----", "-----", "------", "-------", "-----", "---", "---";
        }
        elsif ( $data_type =~ m/VMSTAT_STAT/i ) {
            printf "\n$format",   "Time", "Statistic", "Delta" ;
            printf "$format",   "----", "---------", "-----" ;
        }
        elsif ( $data_type =~ m/VMSTAT_SLAB/i ) {
            printf "\n$format",   "Time", "Cache", "Num", "Total", "Size", "Pages";
            printf "$format",     "----", "-----", "---", "-----", "----", "-----";
        }
        elsif ( $data_type =~ m/MEMINFO/i ) {
            printf "\n$format", "Time", "Statistic", "Value", "Delta" ;
            printf "$format",   "----", "---------", "-----", "-----" ;
        }
        elsif ( $data_type =~ m/IOSTAT/i ) {
            printf "\n$format",   'Time',           'Device',        'ASM',       'Rd Rq/s',       'Wt Rq/s',
                                  'Sct Rd/s',       'Sct Wt/s',      'Avg Sz/Rq', 'Avg Que/Rq',     'AWait (ms)',     'Av Svc(ms)',
                                  'Util%';
            printf "$format",     '----------',     '---------',     '----------', '---------',     '----------',
                                  '----------',     '---------',     '----------', '----------',     '---------',     '----------',
                                  '----------',     ;
        }
        elsif ( $data_type =~ m/MPSTAT/i ) { 
            printf "\n$format", 'Time', 'CPU', 'User%', 'Nice%', 'Sys%', 'IOWait%', 'IRQ%', 'Soft%', 'Steal%', 'Idle%', 'Intr';
            printf "$format",   '----', '---', '-----', '-----', '----', '-------', '----', '-----', '------', '-----', '----';
        }
        elsif ( $data_type =~ m/NETSTAT/i ) {
            printf "\n$format\n", "Time", "Statistic Name", "Delta", "Old Value", "New Value";
            printf "$format\n",   "----", "--------------", "-----", "---------", "---------";
        }
        elsif ( $data_type =~ m/TRACERT/i ) {
            printf "\n$format\n", "Time", "Attempt", "Host", "Trip 1 (ms)", "Trip 2", "Trip 3";
            printf "$format\n",   "----", "-------", "----", "-----------", "------", "------";;
        }
        elsif ( $data_type =~ m/TOP/i ) {
            printf "$format", "Time", "PID", "User", "PR", "Nice", "Status", "Memory", "CPU", "CPU Time", "Cmd";
            printf "$format", "----", "---", "----", "--", "----", "------", "------", "---", "--------", "---";
        }
        elsif ( $data_type =~ m/SLABINFO/i ) {
            printf "\n$format", "Time", "Statistic Name", "Delta", "Old Value", "New Value";
            printf "$format",   "----", "--------------", "-----", "---------", "---------";
        }
        elsif ( $data_type =~m /PS/i ) {
            printf "\n$format",   "Time", "Flag", "Stat", "UID", "PID", "PPID", "CPU", "Pri", "Nice", "Addr", "Size", "WCHAN", "STime", "Time", "Cmd" ;
            printf "$format",     "----", "----", "----", "---", "---", "----", "---", "---", "----", "----", "----", "-----", "-----", "----", "---" ;
        }
        elsif ( $data_type =~m /VXSTAT/i ) {
                printf "\n$format",   'Time',           'Type',        'Name',
                                    'Read Ops',       'Write Ops',   'Block Rds',
                                    'Block Wrts',     'Avg Rd (ms)', 'Avg Wrt (ms)',
                                     'Other' ;
                printf "$format",     '----------',     '----',     '----------',
                                      '----------',     '---------',     '----------',
                                      '----------',     '---------',     '----------',
                                      '----------',     ;
        }
    }
}

__END__



=head1 NAME


=head1 VERSION


=head1 SYNOPSIS

    osw.pl -o OSW_TYPE -f FILE [ -t TIME ] [ -s SEARCH ] [ -y TYPE ] [ -l LIMIT ] [ -v SHOW_ALL_VALUES FLAG ]

           -o meminfo    [ -t TIME] [ -s SEARCH ]

           -o vmstat     [ -t TIME] [ -s SEARCH ] [ -y cpu ] [ -vm_rq INTEGER ] 
           -o vmstat     [ -t TIME] [ -s SEARCH ] [ -y memory ]
           -o vmstat     [ -t TIME] [ -s SEARCH ] [ -y stats ]
           -o vmstat     [ -t TIME] [ -s SEARCH ] [ -y slab ]
           -o vmstat     [ -t TIME] [ -s SEARCH ] [ -y disks ] [ -l INTEGER ]

           -o vxstat     [ -t TIME] [ -s SEARCH ]

           -o netstat    [ -t TIME] [ -s SEARCH ]

           -o iostat     [ -t TIME] [ -s SEARCH ] [ -io_await INTEGER ] [ -io_util INTEGER ] [ -io_svc INTEGER ] [ -io_rd INTEGER ] [ -io_wrt INTEGER ]

           -o slabinfo   [ -t TIME] [ -s SEARCH ]

           -o mpstat     [ -t TIME] [ -s SEARCH ]

           -o tracert    [ -t TIME] [ -s SEARCH ]

           -o top        [ -t TIME] [ -s SEARCH ] [ -top_active ] [ -top_list ]

           -o ps         [ -t TIME] [ -s SEARCH ] [ -ps_pid INTEGER ] [ -ps_state S|R|D ] [ -ps_mem LIMIT ] [ ps_cpu LIMIT ]

           -o vxstat     [ -t TIME] [ -s SEARCH ] [ -y vol ]  [ -v ]
           -o vxstat     [ -t TIME] [ -s SEARCH ] [ -y dm ]   [ -v ]





=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS


=head1 DIAGNOSTICS


=head1 CONFIGURATION AND ENVIRONMENT


=head1 BUGS AND LIMITATIONS


=head1 INCOMPATIBILITIES


=head1 DEPENDENCIES


=head1 AUTHOR



