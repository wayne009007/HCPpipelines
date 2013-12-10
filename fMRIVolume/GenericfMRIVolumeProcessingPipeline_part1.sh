#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL5.0.2 or higher , FreeSurfer (version 5 or higher) , gradunwarp (python code from MGH) 
#  environment: use SetUpHCPPipeline.sh  (or individually set FSLDIR, FREESURFER_HOME, HCPPIPEDIR, PATH - for gradient_unwarp.py)

# make pipeline engine happy...
if [ $# -eq 1 ]
then
    echo "Version unknown..."
    exit 0
fi

########################################## PIPELINE OVERVIEW ########################################## 

# TODO

########################################## OUTPUT DIRECTORIES ########################################## 

# TODO

################################################ SUPPORT FUNCTIONS ##################################################

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

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi

# parse arguments
Path=`getopt1 "--path" $@`  # "$1"
Subject=`getopt1 "--subject" $@`  # "$2"
NameOffMRI=`getopt1 "--fmriname" $@`  # "$6"
fMRITimeSeries=`getopt1 "--fmritcs" $@`  # "$3"
fMRIScout=`getopt1 "--fmriscout" $@`  # "$4"
SpinEchoPhaseEncodeNegative=`getopt1 "--SEPhaseNeg" $@`  # "$7"
SpinEchoPhaseEncodePositive=`getopt1 "--SEPhasePos" $@`  # "$5"
MagnitudeInputName=`getopt1 "--fmapmag" $@`  # "$8" #Expects 4D volume with two 3D timepoints
PhaseInputName=`getopt1 "--fmapphase" $@`  # "$9"
DwellTime=`getopt1 "--echospacing" $@`  # "${11}"
deltaTE=`getopt1 "--echodiff" $@`  # "${12}"
UnwarpDir=`getopt1 "--unwarpdir" $@`  # "${13}"
FinalfMRIResolution=`getopt1 "--fmrires" $@`  # "${14}"
DistortionCorrection=`getopt1 "--dcmethod" $@`  # "${17}" #FIELDMAP or TOPUP (not functional currently)
GradientDistortionCoeffs=`getopt1 "--gdcoeffs" $@`  # "${18}"
TopupConfig=`getopt1 "--topupconfig" $@`  # "${20}" #NONE if Topup is not being used
RUN=`getopt1 "--printcom" $@`  # use ="echo" for just printing everything and not running the commands (default is to run)

# Setup PATHS
PipelineScripts=${HCPPIPEDIR_fMRIVol}
GlobalScripts=${HCPPIPEDIR_Global}
GlobalBinaries=${HCPPIPEDIR_Bin}

#Naming Conventions
T1wImage="T1w_acpc_dc"
T1wRestoreImage="T1w_acpc_dc_restore"
T1wRestoreImageBrain="T1w_acpc_dc_restore_brain"
T1wFolder="T1w" #Location of T1w images
AtlasSpaceFolder="MNINonLinear"
ResultsFolder="Results"
BiasField="BiasField_acpc_dc"
BiasFieldMNI="BiasField"
T1wAtlasName="T1w_restore"
MovementRegressor="Movement_Regressors" #No extension, .txt appended
MotionMatrixFolder="MotionMatrices"
MotionMatrixPrefix="MAT_"
FieldMapOutputName="FieldMap"
MagnitudeOutputName="Magnitude"
MagnitudeBrainOutputName="Magnitude_brain"
ScoutName="Scout"
OrigScoutName="${ScoutName}_orig"
OrigTCSName="${NameOffMRI}_orig"
FreeSurferBrainMask="brainmask_fs"
fMRI2strOutputTransform="${NameOffMRI}2str"
RegOutput="Scout2T1w"
AtlasTransform="acpc_dc2standard"
OutputfMRI2StandardTransform="${NameOffMRI}2standard"
Standard2OutputfMRITransform="standard2${NameOffMRI}"
QAImage="T1wMulEPI"
JacobianOut="Jacobian"


########################################## DO WORK ########################################## 

T1wFolder="$Path"/"$Subject"/"$T1wFolder"
AtlasSpaceFolder="$Path"/"$Subject"/"$AtlasSpaceFolder"
ResultsFolder="$AtlasSpaceFolder"/"$ResultsFolder"/"$NameOffMRI"

fMRIFolder="$Path"/"$Subject"/"$NameOffMRI"
if [ ! -e "$fMRIFolder" ] ; then
  mkdir "$fMRIFolder"
fi
cp "$fMRITimeSeries" "$fMRIFolder"/"$OrigTCSName".nii.gz

#Create fake "Scout" if it doesn't exist
if [ $fMRIScout = "NONE" ] ; then
  ${RUN} ${FSLDIR}/bin/fslroi "$fMRIFolder"/"$OrigTCSName" "$fMRIFolder"/"$OrigScoutName" 0 1
else
  cp "$fMRIScout" "$fMRIFolder"/"$OrigScoutName".nii.gz
fi

#Gradient Distortion Correction of fMRI
if [ ! $GradientDistortionCoeffs = "NONE" ] ; then
    mkdir -p "$fMRIFolder"/GradientDistortionUnwarp
    ${RUN} "$GlobalScripts"/GradientDistortionUnwarp.sh \
	--workingdir="$fMRIFolder"/GradientDistortionUnwarp \
	--coeffs="$GradientDistortionCoeffs" \
	--in="$fMRIFolder"/"$OrigTCSName" \
	--out="$fMRIFolder"/"$NameOffMRI"_gdc \
	--owarp="$fMRIFolder"/"$NameOffMRI"_gdc_warp
	
     mkdir -p "$fMRIFolder"/"$ScoutName"_GradientDistortionUnwarp
     ${RUN} "$GlobalScripts"/GradientDistortionUnwarp.sh \
	 --workingdir="$fMRIFolder"/"$ScoutName"_GradientDistortionUnwarp \
	 --coeffs="$GradientDistortionCoeffs" \
	 --in="$fMRIFolder"/"$OrigScoutName" \
	 --out="$fMRIFolder"/"$ScoutName"_gdc \
	 --owarp="$fMRIFolder"/"$ScoutName"_gdc_warp
else
    echo "NOT PERFORMING GRADIENT DISTORTION CORRECTION"
    ${RUN} ${FSLDIR}/bin/imcp "$fMRIFolder"/"$OrigTCSName" "$fMRIFolder"/"$NameOffMRI"_gdc
    ${RUN} ${FSLDIR}/bin/fslroi "$fMRIFolder"/"$NameOffMRI"_gdc "$fMRIFolder"/"$NameOffMRI"_gdc_warp 0 3
    ${RUN} ${FSLDIR}/bin/fslmaths "$fMRIFolder"/"$NameOffMRI"_gdc_warp -mul 0 "$fMRIFolder"/"$NameOffMRI"_gdc_warp
    ${RUN} ${FSLDIR}/bin/imcp "$fMRIFolder"/"$OrigScoutName" "$fMRIFolder"/"$ScoutName"_gdc
fi

mkdir -p "$fMRIFolder"/MotionCorrection_FLIRTbased
${RUN} "$PipelineScripts"/MotionCorrection_FLIRTbased.sh \
    "$fMRIFolder"/MotionCorrection_FLIRTbased \
    "$fMRIFolder"/"$NameOffMRI"_gdc \
    "$fMRIFolder"/"$ScoutName"_gdc \
    "$fMRIFolder"/"$NameOffMRI"_mc \
    "$fMRIFolder"/"$MovementRegressor" \
    "$fMRIFolder"/"$MotionMatrixFolder" \
    "$MotionMatrixPrefix" 


