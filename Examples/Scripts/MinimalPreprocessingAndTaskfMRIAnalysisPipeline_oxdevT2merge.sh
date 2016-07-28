#!/bin/bash 

# Requirements for this script
#  installed versions of: FSL5.0.2 or higher , FreeSurfer (version 5.2 or higher) , gradunwarp (python code from MGH)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

################################# SUPPORT FUNCTIONS ##################################


Usage() {
  echo "`basename $0`: Script runs the following steps from the HCP pipeline: PreFreeSurfer; FreeSurfer; PostFreeSurfer; fMRIVolume; fMRISurface; TaskfMRIAnalysis "
  echo " "
  echo "Usage: `basename $0` --parameterFile=<InputParameterFile.sh>"
  echo "             [--EnvScript=<SetUpHCPPipeline.sh>]"
  echo "             [--startat=<use if you want to start the pipeline at a later stage; set to the one of the following:>"
  echo "                        <freesurfer> <postfreesurfer> <fMRIVolume> <fMRISurface> <TaskfMRIAnalysis>] "
  echo "             [--finishwith=<use if you want to finish the pipeline before the last step TaskfMRIAnalysis; set to the one of the following (this will be the last run step):>"
  echo "                         <prefreesurfer> <freesurfer> <postfreesurfer> <fMRIVolume> <fMRISurface>] "
  echo "       where <InputParameterFile.sh> contains input parameters and correct paths to directories"
  echo "       where <SetUpHCPPipeline.sh> can be set when you do not want to use the paths that are predefined in the script"
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

###################################### INPUTS #######################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi

# parse arguments
InputParameterFile=`getopt1 "--parameterFile" $@`  # "$1" #Path to InputParameterFile
EnvironmentScript=`getopt1 "--EnvScript" $@`  # "$2" #Environment script
startat=`getopt1 "--startat" $@`
finishwith=`getopt1 "--finishwith" $@`


# Default parameters to run the whole pipeline
SetPreFreeSurfer=1
SetFreeSurfer=1
SetPostFreeSurfer=1
SetfMRIVolume=1
SetfMRISurface=1
SetfMRITask=1

# Check which parts of the pipeline need to be run/skipped
if [[  $startat == "freesurfer" ]] ; then
    echo "Start the pipeline from the Freesurfer part"
    SetPreFreeSurfer=0

    elif [[ $startat == "postfreesurfer" ]] ; then
    echo "Start the pipeline from the PostFreesurfer part"
    SetPreFreeSurfer=0
    SetFreeSurfer=0

    elif [[ $startat == "fMRIVolume" ]] ; then
    echo "Start the pipeline from the fMRIVolume part"
    SetPreFreeSurfer=0
    SetFreeSurfer=0
    SetPostFreeSurfer=0

    elif [[ $startat == "fMRISurface" ]] ; then
    echo "Start the pipeline from the fMRISurface part"
    SetPreFreeSurfer=0
    SetFreeSurfer=0
    SetPostFreeSurfer=0
    SetfMRIVolume=0

    elif [[ $startat == "TaskfMRIAnalysis" ]] ; then
    echo "Start the pipeline from the TaskfMRIAnalysis part"
    SetPreFreeSurfer=0
    SetFreeSurfer=0
    SetPostFreeSurfer=0
    SetfMRIVolume=0
    SetfMRISurface=0

    else
    echo "Run the pipeline from the beginning, from the PreFreeSurfer part"
fi

if  [[  $finishwith == "prefreesurfer" ]] ; then
    echo "Finish the pipeline with the PreFreesurfer part"
    SetFreeSurfer=0
    SetPostFreeSurfer=0
    SetfMRIVolume=0
    SetfMRISurface=0
    SetfMRITask=0

    elif [[  $finishwith == "freesurfer" ]] ; then
    echo "Finish the pipeline with the Freesurfer part"
    SetPostFreeSurfer=0
    SetfMRIVolume=0
    SetfMRISurface=0
    SetfMRITask=0
    
    elif [[ $finishwith == "postfreesurfer" ]] ; then
    echo "Finish the pipeline with the PostFreesurfer part"
    SetfMRIVolume=0
    SetfMRISurface=0
    SetfMRITask=0

    elif [[ $finishwith == "fMRIVolume" ]] ; then
    echo "Finish the pipeline with the fMRIVolume part"
    SetfMRISurface=0
    SetfMRITask=0
    
    elif [[ $finishwith == "fMRISurface" ]] ; then
    echo "Finish the pipeline with the fMRISurface part, last stage of minimal processing pipeline"
    SetfMRITask=0

    else
    echo "Run the pipeline to the end: the whole minimal processing pipeline and task fMRI analysis"
fi


# Set up FreeSurfer (if not already done so in the running environment)
FREESURFER_HOME=/opt/fmrib/freesurfer-5.3.0
. ${FREESURFER_HOME}/SetUpFreeSurfer.sh > /dev/null 2>&1

# Both the SGE and PBS cluster schedulers use the environment variable NSLOTS to indicate the number of cores
# a job will use.  If this environment variable is set, we will use it to determine the number of cores to
# tell recon-all (part of FreeSurfer) to use.
export NSLOTS=1 # set to 1 for FMRIB's cluster, comment out this variable if you want to use the default value of 8.

#Set up pipeline environment variables and software
if [[ ${EnvironmentScript} && ${EnvironmentScript-_} ]] ; then
    . ${EnvironmentScript}
else  
   # Set up specific environment variables for the HCP Pipeline
   # All the following variables can be left as is if the structure of the GIT repository is maintained
   export HCPPIPEDIR=/vols/Data/HCP/GIT/FMRIB_Pipelines/oxdevT2_merge
   export CARET7DIR=/opt/fmrib/workbench/bin_rh_linux64/

   export HCPPIPEDIR_Templates=${HCPPIPEDIR}/global/templates
   export HCPPIPEDIR_Bin=${HCPPIPEDIR}/global/binaries
   export HCPPIPEDIR_Config=${HCPPIPEDIR}/global/config

   export HCPPIPEDIR_PreFS=${HCPPIPEDIR}/PreFreeSurfer/scripts
   export HCPPIPEDIR_FS=${HCPPIPEDIR}/FreeSurfer/scripts
   export HCPPIPEDIR_PostFS=${HCPPIPEDIR}/PostFreeSurfer/scripts
   export HCPPIPEDIR_fMRISurf=${HCPPIPEDIR}/fMRISurface/scripts
   export HCPPIPEDIR_fMRIVol=${HCPPIPEDIR}/fMRIVolume/scripts
   export HCPPIPEDIR_tfMRI=${HCPPIPEDIR}/tfMRI/scripts
   export HCPPIPEDIR_dMRI=${HCPPIPEDIR}/DiffusionPreprocessing/scripts
   export HCPPIPEDIR_dMRITract=${HCPPIPEDIR}/DiffusionTractography/scripts
   export HCPPIPEDIR_Global=${HCPPIPEDIR}/global/scripts
   export HCPPIPEDIR_tfMRIAnalysis=${HCPPIPEDIR}/TaskfMRIAnalysis/scripts
   export MSMBin=/home/fs0/jelena/scratch/MSMv3.0 # ${HCPPIPEDIR}/MSMBinaries
fi

# Importing input variables from the InputParameterFile.sh
if [[ ${InputParameterFile} && ${InputParameterFile-_} ]] ; then
    . ${InputParameterFile}
else
    echo "There is no input file"
    exit 1
fi


# Log the originating call
echo "$@"

if [ X$SGE_ROOT != X ] ; then
    QUEUE="-q long.q"
fi

PRINTCOM=""    # use ="echo" for just printing everything and not running the commands (default is to run, ="")
#PRINTCOM="echo"

# set directory for output files
if [ ! -d "log_files" ] ; then
    mkdir  log_files
fi

# Default values of cluster job IDs
jobidPreFreeSurfer="-1"
jobidFreeSurfer="-1"
jobidPostFreeSurfer="-1"
jobidfMRIVolume="-1"
jobidfMRISurface="-1"

######################################### DO WORK ##########################################

for Subject in $Subjlist ; do
  echo "Subject " $Subject
  
  ###### PreFreeSurfer #####

  #Change input image filenames in the case they have "subject ID" in the filename (replace wildcard %subjectID% with actual ID)
  T1wInputImage="${T1wInputImages}"
  T1wInputImages=`echo ${T1wInputImages} | sed 's/@/ /g'`
  for Tmp in ${T1wInputImages} ; do
      Tt="${StudyFolder}/${Subject}/${Tmp}"
      T1wInputImage=`echo ${T1wInputImage} | sed "s!${Tmp}!${Tt}!"`
  done
  T1wInputImage="`echo ${T1wInputImage} | sed s/%subjectID%/${Subject}/g`"

  if [ ! $FmapMagnitudeInputName = "NONE" ] ; then
    MagnitudeInputName="${StudyFolder}/${Subject}/`echo ${FmapMagnitudeInputName} | sed s/%subjectID%/${Subject}/g`"   #Expects 4D magnitude volume with two 3D timepoints or "NONE" if not used
  else
      MagnitudeInputName="NONE"
  fi

  if [ ! $FmapPhaseInputName = "NONE" ] ; then
    PhaseInputName="${StudyFolder}/${Subject}/`echo ${FmapPhaseInputName} | sed s/%subjectID%/${Subject}/g`" #Expects 3D phase difference volume or "NONE" if not used
  else
      PhaseInputName="NONE"
  fi

  
  if [ ! $SpinEchoPhaseEncodeNegative = "NONE" ] ; then
      SpinEchoPhaseEncodeNegati="${StudyFolder}/${Subject}/`echo ${SpinEchoPhaseEncodeNegative} | sed s/%subjectID%/${Subject}/g`"
  else
      SpinEchoPhaseEncodeNegati="NONE"
  fi
  if [ ! $SpinEchoPhaseEncodePositive = "NONE" ] ; then
      SpinEchoPhaseEncodePositi="${StudyFolder}/${Subject}/`echo ${SpinEchoPhaseEncodePositive} | sed s/%subjectID%/${Subject}/g`"
  else
      SpinEchoPhaseEncodePositi="NONE"
  fi


  # For T2 (if it exists) 
  if [ ! $T2wInputImages = "NONE" ] ; then
      T2wInputImage="${T2wInputImages}"
      T2wInputImages=`echo ${T2wInputImages} | sed 's/@/ /g'`
      for Tmp in ${T2wInputImages} ; do
	  Tt="${StudyFolder}/${Subject}/${Tmp}"
	  T2wInputImage=`echo ${T2wInputImage} | sed "s!${Tmp}!${Tt}!"`
      done
      T2wInputImage="`echo ${T2wInputImage} | sed s/%subjectID%/${Subject}/g`"
  else
   T2wInputImage="NONE"
   T2wTemplate="NONE" 
   T2wTemplateBrain="NONE" 
   T2wTemplate2mm="NONE" 
   T2wSampleSpacing="NONE" 
  fi

  if [ $SetPreFreeSurfer == 1 ] ; then
      jobidPreFreeSurfer=`${FSLDIR}/bin/fsl_sub ${QUEUE} -l ./log_files \
	   ${HCPPIPEDIR}/PreFreeSurfer/PreFreeSurferPipeline.sh \
	  --path="$StudyFolder" \
	  --subject="$Subject" \
	  --t1="$T1wInputImage" \
	  --t2="$T2wInputImage" \
	  --t1template="$T1wTemplate" \
	  --t1templatebrain="$T1wTemplateBrain" \
	  --t1template2mm="$T1wTemplate2mm" \
	  --t2template="$T2wTemplate" \
	  --t2templatebrain="$T2wTemplateBrain" \
	  --t2template2mm="$T2wTemplate2mm" \
	  --templatemask="$TemplateMask" \
	  --template2mmmask="$Template2mmMask" \
	  --brainsize="$BrainSize" \
	  --fnirtconfig="$FNIRTConfig" \
	  --fmapmag="$MagnitudeInputName" \
	  --fmapphase="$PhaseInputName" \
          --fmapgeneralelectric="$GEB0InputName" \
	  --echodiff="$TE" \
	  --SEPhaseNeg="$SpinEchoPhaseEncodeNegati" \
	  --SEPhasePos="$SpinEchoPhaseEncodePositi" \
	  --echospacing="$DwellTime" \
	  --seunwarpdir="$SEUnwarpDir" \
	  --t1samplespacing="$T1wSampleSpacing" \
	  --t2samplespacing="$T2wSampleSpacing" \
	  --unwarpdir="$UnwarpDir" \
	  --gdcoeffs="$GradientDistortionCoeffs" \
	  --avgrdcmethod="$AvgrdcSTRING" \
	  --topupconfig="$TopupConfig" \
	  --printcom=$PRINTCOM`
      
      # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...
      echo "### PreFreeSurfer ###"
      echo "set -- --path=${StudyFolder} \ 
            --subject=${Subject} \ 
            --t1=${T1wInputImage} \ 
            --t2=${T2wInputImage} \  
            --t1template=${T1wTemplate} \ 
            --t1templatebrain=${T1wTemplateBrain} \ 
            --t1template2mm=${T1wTemplate2mm} \ 
            --t2template=${T2wTemplate} \ 
            --t2templatebrain=${T2wTemplateBrain} \ 
            --t2template2mm=${T2wTemplate2mm} \ 
            --templatemask=${TemplateMask} \ 
            --template2mmmask=${Template2mmMask} \ 
            --brainsize=${BrainSize} \ 
            --fnirtconfig=${FNIRTConfig} \ 
            --fmapmag=${MagnitudeInputName} \ 
            --fmapphase=${PhaseInputName} \ 
            --fmapgeneralelectric=${GEB0InputName} \
            --echodiff=${TE} \ 
            --SEPhaseNeg=${SpinEchoPhaseEncodeNegati} \ 
            --SEPhasePos=${SpinEchoPhaseEncodePositi} \ 
            --echospacing=${DwellTime} \ 
            --seunwarpdir=${SEUnwarpDir} \      
            --t1samplespacing=${T1wSampleSpacing} \ 
            --t2samplespacing=${T2wSampleSpacing} \ 
            --unwarpdir=${UnwarpDir} \ 
            --gdcoeffs=${GradientDistortionCoeffs} \ 
            --avgrdcmethod=${AvgrdcSTRING} \ 
            --topupconfig=${TopupConfig} \ 
            --printcom=${PRINTCOM}"

      echo ". ${EnvironmentScript}"     
  fi

  ###### FreeSurfer #####

  # FreeSurfer may require high memory
  QUEUE="-q verylong.q"

   #Input Variables (created in the PreFreesurfer step)
  SubjectDIR="${StudyFolder}/${Subject}/T1w" #Location to put FreeSurfer Subject's Folder
  T1wImage="${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore.nii.gz" #T1w FreeSurfer Input (Full Resolution)
  T1wImageBrain="${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore_brain.nii.gz" #T1w FreeSurfer Input (Full Resolution)
  T2wImage="${StudyFolder}/${Subject}/T1w/T2w_acpc_dc_restore.nii.gz" #T2w FreeSurfer Input (Full Resolution), the script will check if it exists or not

  if [ $SetFreeSurfer == 1 ] ; then
      jobidFreeSurfer=`${FSLDIR}/bin/fsl_sub ${QUEUE} -l ./log_files \
	  -j $jobidPreFreeSurfer \
	  ${HCPPIPEDIR}/FreeSurfer/FreeSurferPipeline.sh \
	  --subject="$Subject" \
	  --subjectDIR="$SubjectDIR" \
	  --t1="$T1wImage" \
	  --t1brain="$T1wImageBrain" \
	  --t2="$T2wImage" \
	  --printcom=$PRINTCOM`
      
        # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

      echo "### Freesurfer ###"
      echo "set -- --subject="$Subject" \ 
          --subjectDIR="$SubjectDIR" \ 
          --t1="$T1wImage" \ 
          --t1brain="$T1wImageBrain" \ 
          --t2="$T2wImage" \ 
          --printcom=$PRINTCOM"
  fi


        ###### PostFreeSurfer #####
  
  QUEUE="-q long.q"

  if [ $SetPostFreeSurfer == 1 ] ; then
      jobidPostFreeSurfer=`${FSLDIR}/bin/fsl_sub ${QUEUE} -l ./log_files \
	  -j $jobidFreeSurfer \
	  ${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipeline.sh \
	  --path="$StudyFolder" \
	  --subject="$Subject" \
	  --surfatlasdir="$SurfaceAtlasDIR" \
	  --grayordinatesdir="$GrayordinatesSpaceDIR" \
	  --grayordinatesres="$GrayordinatesResolutions" \
	  --hiresmesh="$HighResMesh" \
	  --lowresmesh="$LowResMeshes" \
	  --subcortgraylabels="$SubcorticalGrayLabels" \
	  --freesurferlabels="$FreeSurferLabels" \
	  --refmyelinmaps="$ReferenceMyelinMaps" \
	  --regname="$RegName" \
	  --printcom=$PRINTCOM`

      # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...    
      echo  "### PostFreesurfer ###"
      echo "set -- --path="$StudyFolder" \ 
          --subject="$Subject" \ 
          --surfatlasdir="$SurfaceAtlasDIR" \ 
          --grayordinatesdir="$GrayordinatesSpaceDIR" \ 
          --grayordinatesres="$GrayordinatesResolutions" \ 
          --hiresmesh="$HighResMesh" \ 
          --lowresmesh="$LowResMeshes" \ 
          --subcortgraylabels="$SubcorticalGrayLabels" \ 
          --freesurferlabels="$FreeSurferLabels" \ 
          --refmyelinmaps="$ReferenceMyelinMaps" \ 
          --regname="$RegName" \
          --printcom=$PRINTCOM"
  fi
 
       #########  fMRI  #########

  for fMRIName in $Tasklist ; do

          #####  fMRI Volume #####
      fMRITimeSer="${StudyFolder}/${Subject}/`echo ${fMRITimeSeries} | sed s/%TaskName%/${fMRIName}/g  | sed s/%subjectID%/${Subject}/g`"

      if  [ ! $fMRISBRef = "NONE" ] ; then  
	  fMRISBRefe="${StudyFolder}/${Subject}/`echo ${fMRISBRef} | sed s/%TaskName%/${fMRIName}/g  | sed s/%subjectID%/${Subject}/g`"
      else
	   fMRISBRefe="NONE"
      fi
      if [ ! $FmapMagnitudeInputNameForFUNC = "NONE" ] ; then   
          MagnitudeInputNameForFUNC="${StudyFolder}/${Subject}/`echo ${FmapMagnitudeInputNameForFUNC} | sed s/%TaskName%/${fMRIName}/g | sed s/%subjectID%/${Subject}/g`" 
      else 
	  MagnitudeInputNameForFUNC="NONE"
      fi
      if [ ! $FmapPhaseInputNameForFUNC = "NONE" ] ; then
          PhaseInputNameForFUNC="${StudyFolder}/${Subject}/`echo ${FmapPhaseInputNameForFUNC} | sed s/%TaskName%/${fMRIName}/g | sed s/%subjectID%/${Subject}/g`" 
      else
	  PhaseInputNameForFUNC="NONE"
      fi  

      if [ ! $SpinEchoPhaseEncodeNegativeForFUNC = "NONE" ] ; then
	  SpinEchoPhaseEncodeNegat="${StudyFolder}/${Subject}/`echo ${SpinEchoPhaseEncodeNegativeForFUNC} | sed s/%TaskName%/${fMRIName}/g  | sed s/%subjectID%/${Subject}/g`"
      else
	  SpinEchoPhaseEncodeNegat="NONE"
      fi
      if [ ! $SpinEchoPhaseEncodePositiveForFUNC = "NONE" ] ; then
	  SpinEchoPhaseEncodePosit="${StudyFolder}/${Subject}/`echo ${SpinEchoPhaseEncodePositiveForFUNC} | sed s/%TaskName%/${fMRIName}/g  | sed s/%subjectID%/${Subject}/g`"
      else
	  SpinEchoPhaseEncodePosit="NONE"
      fi


      if [ $SetfMRIVolume == 1 ] ; then
	  jobidfMRIVolume=`${FSLDIR}/bin/fsl_sub $QUEUE -l ./log_files \
              -j $jobidPostFreeSurfer \
              ${HCPPIPEDIR}/fMRIVolume/GenericfMRIVolumeProcessingPipeline.sh \
              --path=$StudyFolder \
              --subject=$Subject \
              --fmriname=$fMRIName \
              --fmritcs=$fMRITimeSer \
              --fmriscout=$fMRISBRefe \
              --SEPhaseNeg=$SpinEchoPhaseEncodeNegat \
              --SEPhasePos=$SpinEchoPhaseEncodePosit \
              --fmapmag=$MagnitudeInputNameForFUNC \
              --fmapphase=$PhaseInputNameForFUNC \
              --fmapgeneralelectric=$GEB0InputName \
              --echospacing=$DwellTimeForFUNC \
              --echodiff=$DeltaTE \
              --unwarpdir=$UnwarpdirForFUNC \
              --fmrires=$FinalFMRIResolution \
              --dcmethod=$DistortionCorrection \
              --gdcoeffs=$GradientDistortionCoeffsForFUNC \
              --topupconfig=$TopUpConfigForFUNC \
              --printcom=$PRINTCOM \
              --biascorrection=$BiasCorrection \
              --mctype=${MCType} \
	      --usejacobian`
	  
          # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...
	  echo  "### fMRI Volume  ###"
	  echo "set ----path=$StudyFolder \ 
             --subject=$Subject \ 
             --fmriname=$fMRIName \ 
            --fmritcs=$fMRITimeSer \ 
            --fmriscout=$fMRISBRefe \ 
            --SEPhaseNeg=$SpinEchoPhaseEncodeNegat \ 
            --SEPhasePos=$SpinEchoPhaseEncodePosit \ 
            --fmapmag=$MagnitudeInputNameForFUNC \ 
            --fmapphase=$PhaseInputNameForFUNC \ 
            --fmapgeneralelectric=$GEB0InputName \
            --echospacing=$DwellTimeForFUNC \ 
            --echodiff=$DeltaTE \ 
            --unwarpdir=$UnwarpdirForFUNC \ 
            --fmrires=$FinalFMRIResolution \ 
            --dcmethod=$DistortionCorrection \ 
            --gdcoeffs=$GradientDistortionCoeffsForFUNC \ 
            --topupconfig=$TopUpConfigForFUNC \ 
            --printcom=$PRINTCOM \
            --biascorrection=$BiasCorrection \ 
            --mctype=${MCType}
	    --usejacobian=$UseJacobian"
      fi

          ##### fMRI Surface #####

      if [ $SetfMRISurface == 1 ] ; then 

	  jobidfMRISurface=`${FSLDIR}/bin/fsl_sub $QUEUE -l ./log_files \
              -j $jobidfMRIVolume \
	      ${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh \
	      --path=$StudyFolder \
	      --subject=$Subject \
	      --fmriname=$fMRIName \
	      --lowresmesh=$LowResMeshes \
	      --fmrires=$FinalFMRIResolution \
	      --smoothingFWHM=$SmoothingFWHM \
	      --grayordinatesres=$GrayordinatesResolutions \
	      --regname=$RegName`

          # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...
	  echo "### fMRI Surface ###"
	  echo "set -- --path=$StudyFolder \ 
             --subject=$Subject \ 
             --fmriname=$fMRIName \ 
             --lowresmesh=$LowResMeshes \ 
             --fmrires=$FinalFMRIResolution \ 
             --smoothingFWHM=$SmoothingFWHM \ 
             --grayordinatesres=$GrayordinatesResolutions \ 
             --regname=$RegName"	  
      fi
  done

          ##### Task fMRI Analysis #####

  for fMRIName in $Tasks ; do

      if [ $SetfMRITask == 1 ] ; then

	  if [ $HCPdata == "YES" ] ; then
	      LevelOneTasksList="tfMRI_${fMRIName}_RL@tfMRI_${fMRIName}_LR" #Delimit runs with @ and tasks with space
	      LevelOneFSFsList="tfMRI_${fMRIName}_RL@tfMRI_${fMRIName}_LR" #Delimit runs with @ and tasks with space
	      LevelTwoTaskList="tfMRI_${fMRIName}" #Space delimited list
	      LevelTwoFSFList="tfMRI_${fMRIName}" #Space delimited list

	  else 

	      fMRITimeSer="`echo ${fMRITimeSeries} | sed s/%TaskName%/${fMRIName}/g  | sed s/%subjectID%/${Subject}/g`"
	      
	      basefMRIname=`$FSLDIR/bin/remove_ext  $fMRITimeSer`  # removes the extension of the file

	      #LevelOneTasksList="${basefMRIname}" #Space delimited list
	      #LevelOneFSFsList="${basefMRIname}" #Space delimited list
	      #LevelTwoTaskList="${basefMRIname}" #Space delimited list
	      #LevelTwoFSFList="${basefMRIname}" #Space delimited list

	      LevelOneTasksList="${fMRIName}" #Space delimited list
	      LevelOneFSFsList="${fMRIName}" #Space delimited list
	      LevelTwoTaskList="${fMRIName}" #Space delimited list
	      LevelTwoFSFList="${fMRIName}" #Space delimited list


	      LevelOneFSFPath="`echo ${LevelOneFSFpath} | sed s/%TaskName%/${fMRIName}/g`"

	      # copy design file to the task location
	      jobidCopy=`${FSLDIR}/bin/fsl_sub $QUEUE -l ./log_files \
		  -j $jobidfMRISurface \
		  cp ${LevelOneFSFPath}  ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp200_s4_level1.fsf`

	      echo "cp ${LevelOneFSFPath}  ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp200_s4_level1.fsf"

	      for RegisName in ${RegNames} ; do
		  j=1
		  for Parcellation in ${ParcellationList} ; do
		      ParcellationFile=`echo "${ParcellationFileList}" | cut -d " " -f ${j}`

		      for FinalSmoothingFWHM in $SmoothingList ; do
			  echo $FinalSmoothingFWHM
			  i=1
			  for LevelTwoTask in $LevelTwoTaskList ; do
			      echo "  ${LevelTwoTask}"

			      LevelOneTasks=`echo $LevelOneTasksList | cut -d " " -f $i`
			      LevelOneFSFs=`echo $LevelOneFSFsList | cut -d " " -f $i`
			      LevelTwoTask=`echo $LevelTwoTaskList | cut -d " " -f $i`
			      LevelTwoFSF=`echo $LevelTwoFSFList | cut -d " " -f $i`

			      ${FSLDIR}/bin/fsl_sub $QUEUE -l ./log_files \
				  -j $jobidCopy \
				  ${HCPPIPEDIR}/TaskfMRIAnalysis/TaskfMRIAnalysis.sh \
				  --path=$StudyFolder \
				  --subject=$Subject \
				  --lvl1tasks=$LevelOneTasks \
				  --lvl1fsfs=$LevelOneFSFs \
				  --lvl2task=$LevelTwoTask \
				  --lvl2fsf=$LevelTwoFSF \
				  --lowresmesh=$LowResMeshes \
				  --grayordinatesres=$GrayordinatesResolutions \
				  --origsmoothingFWHM=$SmoothingFWHM \
				  --confound=$Confound \
				  --finalsmoothingFWHM=$FinalSmoothingFWHM \
				  --temporalfilter=$TemporalFilter \
				  --vba=$VolumeBasedProcessing \
				  --regname=$RegisName \
				  --parcellation=$Parcellation \
				  --parcellationfile=$ParcellationFile \
				  --levels=$levels
			      
			      
			      # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...
			      echo " ### TaskfMRIAnalysis ### "
			      echo "set -- --path=$StudyFolder \ 
				  --subject=$Subject \ 
				  --lvl1tasks=$LevelOneTasks \ 
				  --lvl1fsfs=$LevelOneFSFs \ 
				  --lvl2task=$LevelTwoTask \ 
				  --lvl2fsf=$LevelTwoFSF \ 
				  --lowresmesh=$LowResMeshes \ 
				  --grayordinatesres=$GrayordinatesResolutions \ 
				  --origsmoothingFWHM=$SmoothingFWHM \ 
				  --confound=$Confound \ 
				  --finalsmoothingFWHM=$FinalSmoothingFWHM \ 
				  --temporalfilter=$TemporalFilter \ 
				  --vba=$VolumeBasedProcessing \ 
				  --regname=$RegisName \ 
				  --parcellation=$Parcellation \ 
				  --parcellationfile=$ParcellationFile \ 
				  --levels=$levels"

			      i=$(($i+1))

			  done	     
		      done
		      j=$(( ${j}+1 ))
		  done
	      done
	  fi
      fi
  done
done

