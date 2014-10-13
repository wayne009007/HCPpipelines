#!/bin/bash 

Subjlist="4CUUU6TH 8XVEPQTN CNAJK9D6 H7HUJX8M H7T2PZ5Y JF5PMBE2 Q8DH222Z V583N43U VDES69NK VSQBUD58" # Subjlist="100307 103414" #Space delimited list of subject IDs
StudyFolder="/vols/Data/biobank/Phase3/JELENA" #StudyFolder="/vols/Data/HCP/TestStudyFolder" #Location of Subject folders (named by subjectID)
EnvironmentScript="/vols/Data/HCP/GIT/FMRIB_Pipelines/oxdevT2_merge/Examples/Scripts/SetUpHCPPipeline_JBM.sh" #Pipeline environment script
EchoSpacing=0.67 #EPI Echo Spacing for data (in msec)
PEdir=2 #Use 1 for Left-Right Phase Encoding, 2 for Anterior-Posterior
Gdcoeffs="NONE"  # "/vols/Data/HCP/Pipelines/global/config/coeff_SC72C_Skyra.grad" #Coefficients that describe spatial variations of the scanner gradients. Use NONE if not available.

CombineDataFlag=3  # flag for eddy_postproc.sh - if JAC resampling has been used in eddy, decide what to do with the output file
                       # 1 for including in the output and combine only volumes where both LR/RL 
                       #   (or AP/PA) pairs have been acquired  - should be used with HCP data
                       # 2 for including in the output all volumes uncombined (i.e. output file of eddy)
                       # 3 for including in the output only volumes from the direction with more slices - useful for data were one direction has more than 100 volumes and the other less than 10, e.g. Biobank data
                   

# Requirements for this script
#  installed versions of: FSL5.0.5 or higher , FreeSurfer (version 5.2 or higher) , gradunwarp (python code from MGH)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

#Set up pipeline environment variables and software
. ${EnvironmentScript}

# Log the originating call
echo "$@"

#Assume that submission nodes have OPENMP enabled (needed for eddy - at least 8 cores suggested for HCP data)
if [ X$SGE_ROOT != X ] ; then
    QUEUE="-q verylong.q"
fi

PRINTCOM=""


########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the outputs of the PreFreeSurfer Pipeline

######################################### DO WORK ##########################################

for Subject in $Subjlist ; do
  #Input Variables
  SubjectID="$Subject" #Subject ID Name
  RawDataDir="$StudyFolder/$SubjectID/dMRI" #Folder where unprocessed diffusion data are
  PosData="${RawDataDir}/AP.nii.gz" #Data with positive Phase encoding direction. Up to N>=1 series (here N=3), separated by @
  NegData="${RawDataDir}/PA.nii.gz" #Data with negative Phase encoding direction. Up to N>=1 series (here N=3), separated by @
                                                                                 #If corresponding series is missing (e.g. 2 RL series and 1 LR) use EMPTY.
  
  ${FSLDIR}/bin/fsl_sub ${QUEUE} \
     ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline.sh \
      --posData="${PosData}" --negData="${NegData}" \
      --path="${StudyFolder}" --subject="${SubjectID}" \
      --echospacing="${EchoSpacing}" --PEdir=${PEdir} \
      --gdcoeffs="${Gdcoeffs}" \
      --combinedata="$CombineDataFlag" \ 
      --printcom=$PRINTCOM

done

