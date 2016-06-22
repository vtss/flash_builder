properties([
    [$class: 'BuildDiscarderProperty', strategy: [$class: 'LogRotator', artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '', numToKeepStr: '5']],
    [$class: 'GithubProjectProperty', projectUrlStr: 'https://git-ent.microsemi.net/sw/flash_builder'],
])

node('soft03') {

    stage "SCM Checkout"
    checkout([
        $class: 'GitSCM',
        branches: scm.branches,
        doGenerateSubmoduleConfigurations: scm.doGenerateSubmoduleConfigurations,
        extensions: scm.extensions,
        submoduleCfg: [],
        userRemoteConfigs: scm.userRemoteConfigs
    ])

    stage "Clean"
    sh "make clobber"

    stage "Copy artifacts"
    step([$class: 'CopyArtifact', filter: 'images/*', fingerprintArtifacts: true, flatten: true,
          resultVariableSuffix: 'REDBOOT',
          projectName: 'webstax2-redboot', selector: [$class: 'LastCompletedBuildSelector'], target: 'inputs'])
    step([$class: 'CopyArtifact', filter: 'build/obj/*.gz', fingerprintArtifacts: true, flatten: true,
          resultVariableSuffix: 'ECOS',
          projectName: 'webstax2-webstax-3_60_mass', selector: [$class: 'LastCompletedBuildSelector'], target: 'inputs'])
    step([$class: 'CopyArtifact', filter: 'build/obj/results/bringup_*/bringup_*.mfi', fingerprintArtifacts: true, flatten: true,
          resultVariableSuffix: 'LINSTAX',
          projectName: 'webstax2-linstax/4-dev', selector: [$class: 'LastCompletedBuildSelector'], target: 'inputs'])
    
    stage "Build images"
    sh "printenv; git branch; make"

    stage "Archiving results"
    archive 'images/*,status/*'
}

