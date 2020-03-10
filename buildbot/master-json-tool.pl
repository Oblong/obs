#!/usr/bin/perl
# Script to modify master.json for a g-speak release and a new os,
# and to sort the builders for each project alphabetically.
# Does not really parse json, just knows how master.json is usually laid out.
#
# Assumes you already have dev builders for the g-speak and os,
# and want rel builders for the new ones, and to update the dev builders.
# FIXME: control this with options, not hardcoded variables,
# and add options to handle new cef versions, etc.
#
# Usage:
#   vi master-json-tool.pl (and tweak vars)
#   perl master-json-tool.pl < g-speak/master.json > new.json
#   mv new.json g-speak/master.json
#
# Some assembly required.  Do not use while operating heavy machinery.

# Set variables to describe the current latest versions.
# (Skipping this section means the script just sorts builders sections.)
if (1) {
    $oldrel="5.2";   # most recent release version
    $olddev="5.3";   # most recent dev version
    # and the new latest versions we're creating
    $newrel="5.4";
    $newdev="5.5";
    $oldrelre = $oldrel; $oldrelre =~ s/\./\\./;
    $olddevre = $olddev; $olddevre =~ s/\./\\./;

    if (0) {
        # Describe the current latest operating system (leave blank to avoid adding new OS)
        $old_os="osx1014";
        # and the new latest one we're adding
        $new_os="osx1015";
        #$new_os="ubu1910";
    }
}

$in=0;
# For each line of master.json:
while (<STDIN>) {
    if ($in == 0) {
        # If not in a builders section, just print
        print;
        if (/"builders"/) {
            # Entering a building section!
            $in = 1;
        }
    } else {
        # If in a builders section, collect entries until end of section, then sort and print.
        if (/]/) {
            # We've reached the ] that marks the end of the section!
            # Remove commas at end of all output lines...
            grep(s/,$//, @out);
            # Remove duplicates and sort
            %seen=();
            @out = sort(grep({ ! $seen{$_} ++ } @out));
            # Print with comma newline between each line.
            print join(",\n",@out)."\n";
            # Print the closing ]
            print;
            # Reset the state machine and section output array.
            $in = 0;
            undef @out;
        } else {
            # We're somewhere in the middle of a builders section.
            # Append the section's lines to @out.
            # When we see special lines that represent the growing tip,
            # output lines to grow the builder section towards the light,
            # as it were.
            chomp;
            if ($oldrelre ne "" && /$oldrelre/) {
                push(@out, $_);

                # The old latest rel build of something -- keep it, and add one for the new rel build.
                s/$oldrelre/$newrel/g;
                push(@out, $_);

                # It's for the old latest version of ubuntu?  Keep it, and add one for the new latest version of ubuntu.
                if ($old_os ne "" && /"$old_os"/) {
                   s/$old_os/$new_os/g;
                   push(@out, $_);
                }
            } elsif ($olddevre ne "" && /$olddevre/) {
                # e.g. 4.5 becomes 4.7
                s/$olddevre/$newdev/g;
                push(@out, $_);

                # It's for the old latest version of ubuntu?  Keep it, and add one for the new latest version of ubuntu.
                if ($old_os ne "" && /"$old_os"/) {
                   s/$old_os/$new_os/g;
                   push(@out, $_);
                }
            } else {
                # No changes needed
                push(@out, $_);
            }
        }
    }
}
