#!/bin/bash
### Job Name
#PBS -N run_baroclinic_adjustment
### Project Code Allocation
#PBS -A UMCP0020
### Resources
#PBS -l select=1:ncpus=1
### Run Time
#PBS -l walltime=01:00:00
### To the share queue
#PBS -q share
### output
#PBS -o baroclinic_adjustment.log
### error
#PBS -j oe
### Email
#PBS -M zhihua@umd.edu
### Send email on abort, begin and end
#PBS -m abe

### Clear and load all the modules needed
module purge
module load julia 
# module load netcdf
# module load ncarenv/1.3 gnu/10.1.0 ncarcompilers/0.5.0
# module load openmpi/4.1.1 
# module load cuda/4.4.1

export TMPDIR=/glade/scratch/$USER/temp
mkdir -p $TMPDIR

### file to run
#/glade/scratch/knudsenl/BottomBoundaryLayer/
#proj_dir=$HOME/Projects/OANG-tutorial/
#--project=. activates julia environment
julia --project=. baroclinic_adjustment.jl