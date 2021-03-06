#!/usr/bin/env roundup
#

# Let's get started
# -----------------

# Helpers
# -------
. $RERUN || exit 1 ;

# A helper to run rerun.
rerun() {
    command $RERUN -M $RERUN_MODULES "$@"
}

# Mock a command and create an option.
before() {
    mkdir -p $RERUN_MODULES/freddy
    cat > $RERUN_MODULES/freddy/metadata <<EOF
NAME=freddy
DESCRIPTION="mock freddy module created by $(basename $0)"
EOF
    mkdir -p $RERUN_MODULES/freddy/commands/dance
    cat > $RERUN_MODULES/freddy/commands/dance/metadata <<EOF
NAME=dance
DESCRIPTION="mock dance command created by $(basename $0)"
EOF

    return $?
}

# Remove the mock module directory.
after() {
    rm -r $RERUN_MODULES/freddy
}

validate() {
    # Check the option metadata file exists and 
    # the parser no longer contains the option.
    ! test -f $RERUN_MODULES/freddy/options/jumps/metadata
    parser=$RERUN_MODULES/freddy/commands/dance/options.sh
    test -f $parser
    ! grep -q "\-j\|\--jumps)" $parser 
    ! grep -q '[ -z "$JUMPS" ] && JUMPS="1"' $parser
    ! grep -q '"missing required option: --jumps"' $parser
    return $?
}

# The Plan
# --------

describe "rm-option"

# Run it in interactive mode.
it_runs_interactively() {
    # Add option "--jumps|-j <1>"
    rerun stubbs:add-option --module freddy --command dance \
        --option jumps --desc "number of times to jump" \
        --default 1 --required false --export false

    rerun stubbs:rm-option --module freddy --command dance<<EOF
jumps
EOF

    validate
}

# Run the command with all options.
it_runs_fully_optioned() {
    # Add option "--jumps|-j <1>"
    rerun stubbs:add-option --module freddy --command dance \
        --option jumps --desc "number of times to jump" \
        --default 1 --required false --export false

    rerun stubbs:rm-option --module freddy --command dance --option jumps

    validate
}

# Run the command with all options.
it_removes_option_after_last_assignment() {
    # Add freddy:dance option "--jumps|-j <1>"
    rerun stubbs:add-option --module freddy --command dance \
        --option jumps --desc "number of times to jump" \
        --default 1 --required false --export false
    #
    # Add a second freddy:dance option: "--height|-h <5>"
    rerun stubbs:add-option --module freddy --command dance \
        --option height --desc "height to jump" \
        --default 5 --required false --export false
    #
    # Check the command's option assignment
    OPTIONS=( $(.  $RERUN_MODULES/freddy/commands/dance/metadata; echo $OPTIONS) )
    test ${#OPTIONS[*]} = 2
    rerun_list_contains "jumps" "${OPTIONS[@]}"
    rerun_list_contains "height" "${OPTIONS[@]}"
    #
    # Remove --jumps
    rerun stubbs:rm-option --module freddy --command dance --option jumps
    #
    # Check if the option has been unassigned.
    OPTIONS=( $(.  $RERUN_MODULES/freddy/commands/dance/metadata; echo $OPTIONS) )

    test ${#OPTIONS[*]} = 1
    ! rerun_list_contains "jumps" "${OPTIONS[@]}"
    rerun_list_contains "height" "${OPTIONS[@]}"
    # Ensure that the option declaration was removed from the module
    ! test -d $RERUN_MODULES/freddy/options/jumps
    #
    # Remove --height
    rerun stubbs:rm-option --module freddy --command dance --option height
    #
    # Ensure the dance command has no option assignments
    OPTIONS=( $(.  $RERUN_MODULES/freddy/commands/dance/metadata; echo $OPTIONS) )
    test -z "$OPTIONS"
    test ${#OPTIONS[*]} = 0
    #
    # Ensure that the option declaration was removed from the module
    ! test -d $RERUN_MODULES/freddy/options/height
}


it_retains_option_if_assigned_to_command() {
    rerun stubbs:add-option --module freddy --command dance \
        --option jumps --desc "number of times to jump" \
        --default 1 --required false --export false

    mkdir -p $RERUN_MODULES/freddy/commands/pop
    cat > $RERUN_MODULES/freddy/commands/pop/metadata <<EOF
NAME=pop
DESCRIPTION="pop those moves"
OPTIONS=
EOF
    cat > $RERUN_MODULES/freddy/commands/pop/script <<EOF
#!/usr/bin/env bash
#/ command: freddy:pop: "pop those moves"
echo "jumps ($JUMPS)"
EOF
    rerun stubbs:add-option --module freddy --command pop \
        --option jumps --desc "number of times to jump" \
        --default 1 --required false --export false
    rerun stubbs:add-option --module freddy --command pop \
        --option music --desc "music to play" \
        --default lockit --required false --export false
    # Remove freddy:pop --jumps
    rerun stubbs:rm-option --module freddy --command pop --option jumps
    # Jumps option declaration should still exist and tied to dance.
    test -f $RERUN_MODULES/freddy/options/jumps/metadata
    # Ensure the dance command has the jumps assignment
    OPTIONS=( $(.  $RERUN_MODULES/freddy/commands/dance/metadata; echo $OPTIONS) )
    test -n "$OPTIONS"
    test ${#OPTIONS[*]} = 1
    test ${OPTIONS[0]} = "jumps"
}

