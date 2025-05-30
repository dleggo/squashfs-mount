function setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    SQFSDIR=$(mktemp -d)
    export SQFSDIR
    dd=$(mktemp -d)
    (
        umask 022
        cd "$dd" || exit
        mkdir spack-install
        echo "This is file A" >> spack-install/fileA.txt
    )

    mksquashfs "$dd"  ${SQFSDIR}/binaries.sqfs  -quiet -noappend && rm -r "$dd"

    dd=$(mktemp -d)
    (
        umask 022
        cd "$dd" || exit
        mkdir profilers
        echo "profiler stack" >> profilers/fileB.txt
    )
    mksquashfs "$dd"  ${SQFSDIR}/profilers.sqfs -quiet  -noappend && rm -r "$dd"

    dd=$(mktemp -d)
    (
        umask 022
        cd "$dd" || exit
        mkdir tools
        echo "tools stack" >> tools/fileB.txt
    )
    mksquashfs "$dd"  ${SQFSDIR}/tools.sqfs -quiet -noappend && rm -r "$dd"

    dd=$(mktemp -d)
    (
        umask 022
        cd "$dd" || exit
        mkdir tools
        echo "tools stack" >> tools/fileB.txt
    )
    mksquashfs "$dd"  ${SQFSDIR}/tools-offset.sqfs -offset 2048 -quiet -noappend && rm -r "$dd"

}

function teardown() {
    rm -r ${SQFSDIR}
}


@test "mount_single_image" {
    run squashfs-mount ${SQFSDIR}/binaries.sqfs:/user-environment -- cat /user-environment/spack-install/fileA.txt
}

@test "mount_offset_image" {
    run squashfs-mount ${SQFSDIR}/tools-offset.sqfs@2048:/user-tools -- cat /user-tools/tools/fileB.txt
}

@test "mount_offset_image_neg_offset" {
    # offset must be > 0
    run squashfs-mount ${SQFSDIR}/tools-offset.sqfs@-2048434:/user-tools -- cat /user-tools/tools/fileB.txt
    assert_failure
    assert_line  --regexp ".*offset.* must be >0: .*"
}

@test "mount_offset_image_offset_twice" {
    # only one @<offset> is allowed
    run squashfs-mount ${SQFSDIR}/tools-offset.sqfs@2@2:/user-tools -- cat /user-tools/tools/fileB.txt
    assert_failure
    assert_line  --regexp ".*invalid format: .*"
}

@test "mount_images" {
    run squashfs-mount ${SQFSDIR}/binaries.sqfs:/user-environment ${SQFSDIR}/profilers.sqfs:/user-profilers ${SQFSDIR}/tools.sqfs:/user-tools -- cat /user-environment/spack-install/fileA.txt
}


@test "check_environment_variable" {
    run bash -c 'squashfs-mount ${SQFSDIR}/binaries.sqfs:/user-environment ${SQFSDIR}/profilers.sqfs:/user-profilers ${SQFSDIR}/tools.sqfs:/user-tools -- (env | grep UENV_MOUNT_LIST)'
}

@test "invalid_argument" {
    run squashfs-mount invalid_argument -- true
    assert_failure 1
}

@test "noop" {
    # check that no namespace is unshared, when nothing is mounted
    original_mnt=$(readlink /proc/$$/ns/mnt)
    run bash -c 'squashfs-mount -- readlink /proc/$$/ns/mnt'
    assert_output --partial ${original_mnt}
}

@test "fwd_env_ld_library_path" {
    # check forwarding for LD_LIBRARY_PATH
    run bash -c 'SQFSMNT_FWD_LD_LIBRARY_PATH=foo squashfs-mount -- sh -c "env | grep ^LD_LIBRARY_PATH"'
    assert_output --partial "foo"
}
