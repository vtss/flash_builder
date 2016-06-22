properties([
    [$class: 'BuildDiscarderProperty', strategy: [$class: 'LogRotator', artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '', numToKeepStr: '5']],
    [$class: 'GithubProjectProperty', projectUrlStr: 'https://git-ent.microsemi.net/sw/flash_builder'],
])

node('master') {

    stage "SCM Checkout"
    checkout([$class: 'GitSCM',
              branches: scm.branches,
              doGenerateSubmoduleConfigurations: scm.doGenerateSubmoduleConfigurations,
              extensions: scm.extensions, submoduleCfg: [],
              userRemoteConfigs: scm.userRemoteConfigs])

    stage "Clean"
    sh "make clobber"

    stage "Copy artifacts"
    step([$class: 'CopyArtifact', filter: 'images/*', fingerprintArtifacts: true, flatten: true,
          projectName: 'webstax2-redboot', selector: [$class: 'LastCompletedBuildSelector'], target: 'inputs'])
    step([$class: 'CopyArtifact', filter: 'build/obj/*.gz', fingerprintArtifacts: true, flatten: true,
          projectName: 'webstax2-webstax-3_60_mass', selector: [$class: 'LastCompletedBuildSelector'], target: 'inputs'])
    step([$class: 'CopyArtifact', filter: 'build/obj/results/bringup_*.mk/bringup_*.mfi', fingerprintArtifacts: true, flatten: true,
          projectName: 'WebStax-Release', selector: [$class: 'LastCompletedBuildSelector'], target: 'inputs'])
    
    stage "Build images"
    sh "make"

    stage "Archiving results"
    archive 'images/*,status/*'
}

