#!/bin/bash 

Subjlist="21 22" #Space delimited list of subject IDs
StudyFolder="/home/fs0/rosas/scratch/analysis" #Location of Subject folders (named by subjectID)
EnvironmentScript="/home/fs0/rosas/scratch/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

# Requirements for this script
#  installed versions of: FSL5.0.2 or higher , FreeSurfer (version 5.2 or higher) , gradunwarp (python code from MGH)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

#Set up pipeline environment variables and software
. ${EnvironmentScript}

# Log the originating call
echo "$@"

if [ X$SGE_ROOT != X ] ; then
    QUEUE="-q long.q"
fi

PRINTCOM=""
#PRINTCOM="echo"
#QUEUE="-q veryshort.q"

########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the outputs of the FreeSurfer Pipeline
# SAME INPUTS AS FMRI VOLUME PROCESSING
######################################### DO WORK ##########################################


Tasklist="v t"

for Subject in $Subjlist ; do
  for fMRIName in $Tasklist ; do
    LowResMesh="32" #Needs to match what is in PostFreeSurfer
    FinalfMRIResolution="2" #Needs to match what is in fMRIVolume
    SmoothingFWHM="2" #Recommended to be roughly the voxel size
    GrayordinatesResolution="2" #Needs to match what is in PostFreeSurfer. Could be the same as FinalfRMIResolution something different, which will call a different module for subcortical processing

    ${FSLDIR}/bin/fsl_sub $QUEUE \
      ${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh \
      --path=$StudyFolder \
      --subject=$Subject \
      --fmriname=$fMRIName \
      --lowresmesh=$LowResMesh \
      --fmrires=$FinalfMRIResolution \
      --smoothingFWHM=$SmoothingFWHM \
      --grayordinatesres=$GrayordinatesResolution 

  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

      echo "set -- --path=$StudyFolder \
      --subject=$Subject \
      --fmriname=$fMRIName \
      --lowresmesh=$LowResMesh \
      --fmrires=$FinalfMRIResolution \
      --smoothingFWHM=$SmoothingFWHM \
      --grayordinatesres=$GrayordinatesResolution"

      echo ". ${EnvironmentScript}"
            
   done
done

