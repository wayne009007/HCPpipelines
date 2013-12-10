#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL5.0.1 or higher , FreeSurfer (version 5 or higher) , gradunwarp (python code from MGH)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

# make pipeline engine happy...
if [ $# -eq 1 ] ; then
    echo "Version unknown..."
    exit 0
fi


########################################## PIPELINE OVERVIEW ########################################## 

#TODO

########################################## OUTPUT DIRECTORIES ########################################## 

## NB: NO assumption is made about the input paths with respect to the output directories - they can be totally different.  All input are taken directly from the input variables without additions or modifications.

# NB: Output directories T1wFolder and T2wFolder MUST be different (as various output subdirectories containing standardly named files, e.g. full2std.mat, would overwrite each other) so if this script is modified, then keep these output directories distinct


# Output path specifiers:
#
# ${StudyFolder} is an input parameter
# ${Subject} is an input parameter

# Main output directories
# T1wFolder=${StudyFolder}/${Subject}/T1w
# T2wFolder=${StudyFolder}/${Subject}/T2w      ------------------IF THERE IS T2
# AtlasSpaceFolder=${StudyFolder}/${Subject}/MNINonLinear

# All outputs are within the directory: ${StudyFolder}/${Subject}
# The list of output directories are the following

#    T1w/T1w${i}_GradientDistortionUnwarp
#    T1w/AverageT1wImages
#    T1w/ACPCAlignment
#    T1w/BrainExtraction_FNIRTbased
# and the above for T2w as well (s/T1w/T2w/g)  ------------------IF THERE IS T2

#    T2w/T2wToT1wDistortionCorrectAndReg
#    T1w/BiasFieldCorrection_sqrtT1wXT1w 
#    MNINonLinear
# If there is only T1 image:
#    ROSER: CHECK OUTPUT DIRECTORIES????????????


# Also exist:
#    T1w/xfms/
#    T2w/xfms/                                ------------------IF THERE IS T2
#    MNINonLinear/xfms/

########################################## SUPPORT FUNCTIONS ########################################## 

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

# Input Variables
StudyFolder=`getopt1 "--path" $@`  # "$1" #Path to subject's data folder
Subject=`getopt1 "--subject" $@`  # "$2" #SubjectID
T1wInputImages=`getopt1 "--t1" $@`  # "$3" #T1w1@T1w2@etc..
T2wInputImages=`getopt1 "--t2" $@`  # "$4" #T2w1@T2w2@etc..
T1wTemplate=`getopt1 "--t1template" $@`  # "$5" #MNI template
T1wTemplateBrain=`getopt1 "--t1templatebrain" $@`  # "$6" #Brain extracted MNI T1wTemplate
T1wTemplate2mm=`getopt1 "--t1template2mm" $@`  # "$7" #MNI2mm T1wTemplate
T2wTemplate=`getopt1 "--t2template" $@`  # "${8}" #MNI T2wTemplate
T2wTemplateBrain=`getopt1 "--t2templatebrain" $@`  # "$9" #Brain extracted MNI T2wTemplate
T2wTemplate2mm=`getopt1 "--t2template2mm" $@`  # "${10}" #MNI2mm T2wTemplate
TemplateMask=`getopt1 "--templatemask" $@`  # "${11}" #Brain mask MNI Template
Template2mmMask=`getopt1 "--template2mmmask" $@`  # "${12}" #Brain mask MNI2mm Template 
BrainSize=`getopt1 "--brainsize" $@`  # "${13}" #StandardFOV mask for averaging structurals
FNIRTConfig=`getopt1 "--fnirtconfig" $@`  # "${14}" #FNIRT 2mm T1w Config
MagnitudeInputName=`getopt1 "--fmapmag" $@`  # "${16}" #Expects 4D magitude volume with two 3D timepoints
PhaseInputName=`getopt1 "--fmapphase" $@`  # "${17}" #Expects 3D phase difference volume
TE=`getopt1 "--echospacing" $@`  # "${18}" #delta TE for field map
T1wSampleSpacing=`getopt1 "--t1samplespacing" $@`  # "${19}" #DICOM field (0019,1018)
T2wSampleSpacing=`getopt1 "--t2samplespacing" $@`  # "${20}" #DICOM field (0019,1018) 
UnwarpDir=`getopt1 "--unwarpdir" $@`  # "${21}" #z appears to be best
GradientDistortionCoeffs=`getopt1 "--gdcoeffs" $@`  # "${25}" #Select correct coeffs for scanner or "NONE" to turn off
AvgrdcSTRING=`getopt1 "--avgrdcmethod" $@`  # "${26}" #Averaging and readout distortion correction methods: "NONE" = average any repeats with no readout correction "FIELDMAP" = average any repeats and use field map for readout correction "TOPUP" = average and distortion correct at the same time with topup/applytopup only works for 2 images currently
TopupConfig=`getopt1 "--topupconfig" $@`  # "${27}" #Config for topup or "NONE" if not used
RUN=`getopt1 "--printcom" $@`  # use ="echo" for just printing everything and not running the commands (default is to run)

echo "$StudyFolder $Subject"

# Paths for scripts etc (uses variables defined in SetUpHCPPipeline.sh)
PipelineScripts=${HCPPIPEDIR_PreFS}
GlobalScripts=${HCPPIPEDIR_Global}

if [ $T2wInputImages = "NONE" ] ; then
 echo "RUNNING PROTOCOL WITHOUT T2w"
   Modalities="T1w"
else
 echo "USING T1w AND T2w SCANS"
   Modalities="T1w T2w"
fi


# Naming Conventions and Build Paths
T1wImage="T1w"
T1wFolder="T1w" #Location of T1w images
T1wFolder=${StudyFolder}/${Subject}/${T1wFolder}
if [ ! $T2wInputImages = "NONE" ] ; then
   T2wImage="T2w" 
   T2wFolder="T2w" #Location of T2w images
   T2wFolder=${StudyFolder}/${Subject}/${T2wFolder}
fi
AtlasSpaceFolder="MNINonLinear"
AtlasSpaceFolder=${StudyFolder}/${Subject}/${AtlasSpaceFolder}

echo "$T1wFolder $T2wFolder $AtlasSpaceFolder"

#### Atlas Registration to MNI152: FLIRT + FNIRT  #Also applies registration to T1w and T2w images ####
#Consider combining all transforms and recreating files with single resampling steps
if [ ! $T2winputImages = "NONE" ] ; then
    regT2=${T1wFolder}/${T2wImage}_acpc_dc                        
    regT2rest=${T1wFolder}/${T2wImage}_acpc_dc_restore            
    regT2restbrain=${T1wFolder}/${T2wImage}_acpc_dc_restore_brain 
    reg_ot2=${AtlasSpaceFolder}/${T2wImage}
    reg_ot2rest=${AtlasSpaceFolder}/${T2wImage}_restore
    reg_ot2restbrain=${AtlasSpaceFolder}/${T2wImage}_restore_brain
else
    regT2="NONE"                        
    regT2rest="NONE"            
    regT2restbrain="NONE" 
    reg_ot2="NONE"
    reg_ot2rest="NONE"
    reg_ot2restbrain="NONE"
fi
echo "start atlas registration"
 
${RUN} ${PipelineScripts}/AtlasRegistrationToMNI152_FLIRTandFNIRT.sh \
    --workingdir=${AtlasSpaceFolder}  \
    --t1=${T1wFolder}/${T1wImage}_acpc_dc \
    --t1rest=${T1wFolder}/${T1wImage}_acpc_dc_restore \
    --t1restbrain=${T1wFolder}/${T1wImage}_acpc_dc_restore_brain \
    --t2=${regT2} \
    --t2rest=${regT2rest} \
    --t2restbrain=${regT2restbrain} \
    --ref=${T1wTemplate} \
    --refbrain=${T1wTemplateBrain} \
    --refmask=${TemplateMask} \
    --ref2mm=${T1wTemplate2mm} \
    --ref2mmmask=${Template2mmMask} \
    --owarp=${AtlasSpaceFolder}/xfms/acpc_dc2standard.nii.gz \
    --oinvwarp=${AtlasSpaceFolder}/xfms/standard2acpc_dc.nii.gz \
    --ot1=${AtlasSpaceFolder}/${T1wImage} \
    --ot1rest=${AtlasSpaceFolder}/${T1wImage}_restore \
    --ot1restbrain=${AtlasSpaceFolder}/${T1wImage}_restore_brain \
    --ot2=${reg_ot2} \
    --ot2rest=${reg_ot2rest} \
    --ot2restbrain=${reg_ot2restbrain} \
    --fnirtconfig=${FNIRTConfig}

#### Next stage: FreeSurfer/FreeSurferPipeline.sh

