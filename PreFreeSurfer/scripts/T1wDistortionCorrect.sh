#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL5.0.1 or later, gradunwarp python package (from MGH)
#  environment: FSLDIR and PATH for gradient_unwarp.py

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Script for performing gradient-nonlinearity and susceptibility-inducted distortion correction on T1w images"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working directory>]"
  echo "            --t1=<input T1w image>"
  echo "            --t1brain=<input T1w brain-extracted image>"
  echo "            --fmapmag=<input fieldmap magnitude image>"
  echo "            --fmapphase=<input fieldmap phase images (single 4D image containing 2x3D volumes)>"
  echo "            --echodiff=<echo time difference for fieldmap images (in milliseconds)>"
  echo "            --t1sampspacing=<sample spacing (readout direction) of T1w image - in seconds>"
  echo "            --unwarpdir=<direction of distortion according to voxel axes (post reorient2std)>"
  echo "            --ot1=<output corrected T1w image>"
  echo "            --ot1brain=<output corrected, brain-extracted T1w image>"
  echo "            --ot1warp=<output warpfield for distortion correction of T1w image>"
  echo "            [--gdcoeffs=<gradient distortion coefficients (SIEMENS file)>]"
}

# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in $@ ; do
	if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
	    echo $fn | sed "s/^${sopt}=//"
	    return 0
	fi
    done
}

defaultopt() {
    echo $1
}

################################################### OUTPUT FILES #####################################################

# For distortion correction:
#
# Output files (in $WD): Magnitude  Magnitude_brain  Phase  FieldMap
#                        Magnitude_brain_warppedT1w  Magnitude_brain_warppedT1w2${TXwImageBrainBasename}
#                        fieldmap2${T1wImageBrainBasename}.mat   FieldMap2${T1wImageBrainBasename}
#                        FieldMap2${T1wImageBrainBasename}_ShiftMap  
#                        FieldMap2${T1wImageBrainBasename}_Warp ${T1wImageBasename}  ${T1wImageBrainBasename}
#        Plus the versions with T1w -> T2w
#
# Output files (not in $WD):  ${OutputT1wTransform}   ${OutputT1wImage}  ${OutputT1wImageBrain}
#        Note that these outputs are actually copies of the last three entries in the $WD list
#
#
# For registration:
#
# Output images (in $WD/T2w2T1w):  sqrtT1wbyT2w  T2w_reg.mat  T2w_reg_init.mat
#                                  T2w_dc_reg  (the warp field)
#                                  T2w_reg     (the warped image)
# Output images (not in $WD):  ${OutputT2wTransform}   ${OutputT2wImage}
#        Note that these outputs are copies of the last two images (respectively) from the T2w2T1w subdirectory

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
# if [ $# -lt 12 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
T1wImage=`getopt1 "--t1" $@`  # "$2"
T1wImageBrain=`getopt1 "--t1brain" $@`  # "$3"
MagnitudeInputName=`getopt1 "--fmapmag" $@`  # "$4"
PhaseInputName=`getopt1 "--fmapphase" $@`  # "$5"
TE=`getopt1 "--echodiff" $@`  # "$6"
T1wSampleSpacing=`getopt1 "--t1sampspacing" $@`  # "$7"
UnwarpDir=`getopt1 "--unwarpdir" $@`  # "${8}"
OutputT1wImage=`getopt1 "--ot1" $@`  # "${9}"
OutputT1wImageBrain=`getopt1 "--ot1brain" $@`  # "${10}"
OutputT1wTransform=`getopt1 "--ot1warp" $@`  # "${11}"
GradientDistortionCoeffs=`getopt1 "--gdcoeffs" $@`  # "${12}"

# default parameters
GlobalScripts=${HCPPIPEDIR_Global}
WD=`defaultopt $WD .`

T1wImage=`${FSLDIR}/bin/remove_ext $T1wImage`
T1wImageBrain=`${FSLDIR}/bin/remove_ext $T1wImageBrain`
#RS#T2wImage=`${FSLDIR}/bin/remove_ext $T2wImage`
#RS#T2wImageBrain=`${FSLDIR}/bin/remove_ext $T2wImageBrain`

T1wImageBrainBasename=`basename "$T1wImageBrain"`
T1wImageBasename=`basename "$T1wImage"`
#RS#T2wImageBrainBasename=`basename "$T2wImageBrain"`
#RS#T2wImageBasename=`basename "$T2wImage"`

#RS#Modalities="T1w T2w"

echo " "
echo " START: T1wDistortionCorrection"

mkdir -p $WD
mkdir -p ${WD}/FieldMap

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt


########################################## DO WORK ########################################## 

### Create fieldmaps (and apply gradient non-linearity distortion correction)
echo " "
echo " "
echo " "
#echo ${GlobalScripts}/FieldMapPreprocessingAll.sh ${WD}/FieldMap ${MagnitudeInputName} ${PhaseInputName} ${TE} ${WD}/Magnitude ${WD}/Magnitude_brain ${WD}/Phase ${WD}/FieldMap ${GradientDistortionCoeffs} ${GlobalScripts}

${GlobalScripts}/FieldMapPreprocessingAll.sh \
    --workingdir=${WD}/FieldMap \
    --fmapmag=${MagnitudeInputName} \
    --fmapphase=${PhaseInputName} \
    --echodiff=${TE} \
    --ofmapmag=${WD}/Magnitude \
    --ofmapmagbrain=${WD}/Magnitude_brain \
    --ofmap=${WD}/FieldMap \
    --gdcoeffs=${GradientDistortionCoeffs}



### ONLY T1 MODALITY ###

#RS#for TXw in $Modalities ; do
    # set up required variables
#RS#    if [ $TXw = T1w ] ; then
#RS#	TXwImage=$T1wImage
#RS#	TXwImageBrain=$T1wImageBrain
#RS#	TXwSampleSpacing=$T1wSampleSpacing
#RS#	TXwImageBasename=$T1wImageBasename
#RS#	TXwImageBrainBasename=$T1wImageBrainBasename
#RS#    else
#RS#	TXwImage=$T2wImage
#RS#	TXwImageBrain=$T2wImageBrain
#RS#	TXwSampleSpacing=$T2wSampleSpacing
#RS#	TXwImageBasename=$T2wImageBasename
#RS#	TXwImageBrainBasename=$T2wImageBrainBasename
#RS#    fi

    # Forward warp the fieldmap magnitude and register to TXw image (transform phase image too)
    ${FSLDIR}/bin/fugue --loadfmap=${WD}/FieldMap --dwell=${T1wSampleSpacing} --saveshift=${WD}/FieldMap_ShiftMap${T1w}.nii.gz    
    ${FSLDIR}/bin/convertwarp --relout --rel --ref=${WD}/Magnitude --shiftmap=${WD}/FieldMap_ShiftMap${T1w}.nii.gz --shiftdir=${UnwarpDir} --out=${WD}/FieldMap_Warp${T1w}.nii.gz    
    ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Magnitude -r ${WD}/Magnitude -w ${WD}/FieldMap_Warp${T1w}.nii.gz -o ${WD}/Magnitude_warpped${T1w}

    ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_warpped${T1w} -ref ${T1wImage} -out ${WD}/Magnitude_warpped${T1w}2${T1wImageBasename} -omat ${WD}/Fieldmap2${T1wImageBasename}.mat -searchrx -30 30 -searchry -30 30 -searchrz -30 30
    ${FSLDIR}/bin/flirt -in ${WD}/FieldMap.nii.gz -ref ${T1wImage} -applyxfm -init ${WD}/Fieldmap2${T1wImageBasename}.mat -out ${WD}/FieldMap2${T1wImageBasename}
    
    
    # Convert to shift map then to warp field and unwarp the TXw
    ${FSLDIR}/bin/fugue --loadfmap=${WD}/FieldMap2${T1wImageBasename} --dwell=${T1wSampleSpacing} --saveshift=${WD}/FieldMap2${T1wImageBasename}_ShiftMap.nii.gz    
    ${FSLDIR}/bin/convertwarp --relout --rel --ref=${T1wImageBrain} --shiftmap=${WD}/FieldMap2${T1wImageBasename}_ShiftMap.nii.gz --shiftdir=${UnwarpDir} --out=${WD}/FieldMap2${T1wImageBasename}_Warp.nii.gz    
    ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T1wImage} -r ${T1wImage} -w ${WD}/FieldMap2${T1wImageBasename}_Warp.nii.gz -o ${WD}/${T1wImageBasename}
    
    # Make a brain image (transform to make a mask, then apply it)
    ${FSLDIR}/bin/applywarp --rel --interp=nn -i ${T1wImageBrain} -r ${T1wImageBrain} -w ${WD}/FieldMap2${T1wImageBasename}_Warp.nii.gz -o ${WD}/${T1wImageBrainBasename} 
    ${FSLDIR}/bin/fslmaths ${WD}/${T1wImageBasename} -mas ${WD}/${T1wImageBrainBasename} ${WD}/${T1wImageBrainBasename}
    
    # Copy files to specified destinations
    ${FSLDIR}/bin/imcp ${WD}/FieldMap2${T1wImageBasename}_Warp ${OutputT1wTransform}
    ${FSLDIR}/bin/imcp ${WD}/${T1wImageBasename} ${OutputT1wImage}
    ${FSLDIR}/bin/imcp ${WD}/${T1wImageBrainBasename} ${OutputT1wImageBrain}
   
    
#RS#done

### END LOOP over modalities ### only t1


### Now do T2w to T1w registration
#RS#mkdir -p ${WD}/T2w2T1w
    
#RS## Main registration: between corrected T2w and corrected T1w
#RS#${FSLDIR}/bin/epi_reg --epi=${WD}/${T2wImageBrainBasename} --t1=${WD}/${T1wImageBasename} --t1brain=${WD}/${T1wImageBrainBasename} --out=${WD}/T2w2T1w/T2w_reg
    
#RS## Make a warpfield directly from original (non-corrected) T2w to corrected T1w  (and apply it)
#RS#${FSLDIR}/bin/convertwarp --relout --rel --ref=${T1wImage} --warp1=${WD}/FieldMap2${T2wImageBasename}_Warp.nii.gz --postmat=${WD}/T2w2T1w/T2w_reg.mat -o ${WD}/T2w2T1w/T2w_dc_reg
    
#RS#${FSLDIR}/bin/applywarp --rel --interp=spline --in=${T2wImage} --ref=${T1wImage} --warp=${WD}/T2w2T1w/T2w_dc_reg --out=${WD}/T2w2T1w/T2w_reg
   
# Add 1 to avoid exact zeros within the image (a problem for myelin mapping?)
#RS#${FSLDIR}/bin/fslmaths ${WD}/T2w2T1w/T2w_reg.nii.gz -add 1 ${WD}/T2w2T1w/T2w_reg.nii.gz -odt float

# QA image
#RS#${FSLDIR}/bin/fslmaths ${WD}/T2w2T1w/T2w_reg -mul ${T1wImage} -sqrt ${WD}/T2w2T1w/sqrtT1wbyT2w -odt float
    
# Copy files to specified destinations
#RS#${FSLDIR}/bin/imcp ${WD}/T2w2T1w/T2w_dc_reg ${OutputT2wTransform}
#RS#${FSLDIR}/bin/imcp ${WD}/T2w2T1w/T2w_reg ${OutputT2wImage}

echo " "
echo " END: T1wDistortionCorrect"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ########################################## 

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
#RS#echo "# View registration result of corrected T2w to corrected T1w image: showing both images + sqrt(T1w*T2w)" >> $WD/qa.txt
#RS#echo "fslview ${OutputT1wImage} ${OutputT2wImage} ${WD}/T2w2T1w/sqrtT1wbyT2w" >> $WD/qa.txt
echo "# Compare pre- and post-distortion correction for T1w" >> $WD/qa.txt
echo "fslview ${T1wImage} ${OutputT1wImage}" >> $WD/qa.txt
#RS#echo "# Compare pre- and post-distortion correction for T2w" >> $WD/qa.txt
#RS#echo "fslview ${T2wImage} ${WD}/${T2wImageBasename}" >> $WD/qa.txt

##############################################################################################

