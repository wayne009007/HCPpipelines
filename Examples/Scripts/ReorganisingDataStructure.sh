#!/bin/bash

# The purpose of this script is to reorganise the data location structure and adjust the naming and locations to the HCP pipeline script PreFreeSurferTofMRISurfaceProcessingPipeline.sh

# The data locations and naming conventions must be arranged as follows:
#   - a single top-level directory must contain one subdirectory for each subject
#   - within each subject directory there must be all the necessary image files
#   - image files cannot be within separate subdirectories
# Example of folder structure: 
#     /home/fs0/myname/scratch/outdir/subname1/
#     /home/fs0/myname/scratch/outdir/subname2/

# The script creates new folder $outdir/$subname in which it locates symbolic links to original images (structural, functional, fieldmaps) and generalizes image names.

outdir="/home/fs0/jmouthuy/scratch/testForHCPdata" # output folder
topdir="/vols/Data/bishop/F1_anxiety_rest" # folder with all subject folders

#dirlist="controls*/run* disease/AD*/run1"   # an unusual (and complicated) case
dirlist="sub1*/F3T*" # list of subject (sub)folders that contain images


# create $outdir if it does not exist
if [ ! -d $outdir ] ; then
    mkdir $outdir
fi

cd $topdir
for dname in $dirlist ; do

  cd $dname
  pwd 
  subname=`echo $dname | sed 's@/@_@g'`   # a default, but could be changed; name of the subject folder in the output folder

  mkdir $outdir/$subname # creating folder for each subject
  
  # creating symbolic links of the images after checking if the image exists
  if  [ -e images_*mprax*[0-9].nii.gz ] ; then
      ln -s $topdir/$dname/images_*mprax*[0-9].nii.gz $outdir/$subname/T1.nii.gz
  else
      echo "There is a problem with structural (e.g. no image, more then specified)"
  fi

  if [ -e images_*SafeRest*.nii.gz ] ; then
      ln -s $topdir/$dname/images_*SafeRest*.nii.gz $outdir/$subname/safeRestfMRI.nii.gz
  else
      echo "There is a problem with functional (e.g. no image, more then specified)"
  fi

  if [ -e images_*AnxiousRest*.nii.gz ] ; then
      ln -s $topdir/$dname/images_*AnxiousRest*.nii.gz $outdir/$subname/anxiousRestfMRI.nii.gz
  else
      echo "There is a problem with functional (e.g. no image, more then specified)"
  fi

  fmapmag=`ls images_*_fieldmap*2001.nii.gz | head -n 1` 
  if [ -e "$fmapmag" ] ; then
      ln -s $topdir/$dname/$fmapmag $outdir/$subname/fmap_mag.nii.gz
  else
      echo "There is a problem with fieldmaps (e.g. no image, more then specified)"
  fi
  
  fmapphase=`ls images_*_fieldmap*2001.nii.gz | tail -n 1`
  if [ -e "$fmapphase" ] ; then      
      ln -s $topdir/$dname/$fmapphase $outdir/$subname/fmap_phase.nii.gz
  else
      echo "There is a problem with fielmaps (e.g. no image, more then specified)"
  fi

  cd $topdir

done
