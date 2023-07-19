#! /bin/bash

read_version_file() {
    local version_file=$1
    local cur_version=""
    cur_version=$(grep -m 1 "version:" "$version_file" | sed -E 's/version:\s*([0-9]+\.[0-9]+\.[0-9]+)(\+[0-9]+)?(-rc[0-9]+)?(.*)?/\1\2\3/')

    # On MacOS replace 'version: ' prefix with ''
    cur_version="${cur_version/"version: "/}"

    echo "$cur_version"
}

extract_version_components() {
    local version_string="$1"

    # Regular expression pattern to extract version components
    local pattern="^([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)(-rc[0-9]+)?$"

    if [[ $version_string =~ $pattern ]]; then
        local major="${BASH_REMATCH[1]}"
        local minor="${BASH_REMATCH[2]}"
        local patch="${BASH_REMATCH[3]}"
        local build_number="${BASH_REMATCH[4]}"
        local rc="${BASH_REMATCH[5]}"

        # Remove 'rc' prefix if it exists
        rc="${rc/"rc"/""}"

        # Return the extracted components as an array
        echo "$major $minor $patch $build_number ${rc:1}"
    else
        echo "Invalid version string: $version_string"
        exit 1
    fi
}

compare_versions() {
    # Extract the tag version from the environment variable
    local base_version_components=$1
    local new_version_components=$2

    read -r new_major new_minor new_patch new_build_number new_rc <<<"$new_version_components"

    # current version components
    read -r current_major current_minor current_patch current_build_number current_rc <<<"$base_version_components"

    if [[ -n "$new_build_number" && "$new_build_number" != $((current_build_number + 1)) ]]; then
        echo "Incorrect build number. Expected it to be '$((current_build_number + 1))'."

        exit 31
    fi

    # Check if tag version is greater by 1 in any component of current version
    if [ "$new_major" -eq $((current_major + 1)) ] &&
        [ "$new_minor" -eq 0 ] &&
        [ "$new_patch" -eq 0 ]; then
        echo new_release_type=major

    elif [ "$new_major" -eq "$current_major" ] &&
        [ "$new_minor" -eq "$((current_minor + 1))" ] &&
        [ "$new_patch" -eq 0 ]; then
        echo new_release_type=minor

    elif [ "$new_major" -eq "$current_major" ] &&
        [ "$new_minor" -eq "$current_minor" ] &&
        [ "$new_patch" -eq "$((current_patch + 1))" ]; then
        echo new_release_type=patch

    else
        echo "Tag version is not greater by 1 in any component when compared with current version"

        exit 3
    fi
}

generate_semantic_version() {
    local prev_version_components=$1
    local release_type=$2
    local release_candidate=$3

    local build_number=0
    local new_version_only=""
    local new_build_version=""

    read -r major minor patch build_number rc <<<"$prev_version_components"

    case "$release_type" in
    "major")
        major=$((major + 1))
        minor=0
        patch=0
        ;;
    "minor")
        minor=$((minor + 1))
        patch=0
        ;;
    "patch")
        patch=$((patch + 1))
        ;;
    "current")
        # Use current version from version file
        ;;
    *)
        echo "Invalid version type: '$1'. Valid type is major, minor, patch, current or 'use test version'"
        exit 4
        ;;
    esac

    if [ "$release_candidate" = true ]; then

        # if existing release is rc, then increment rc count
        if [ -n "$rc" ] && [ "$release_type" = "current" ]; then
            rc="$((rc + 1))"

        elif [ "$release_type" != "current" ]; then
            rc="1"

        else
            echo "Cannot mark an existing non-rc release as a release candidate (rc)."
            exit 6
        fi
    else
        rc=""
    fi

    if [[ "$release_type" != "current" ]]; then
        build_number=$((build_number + 1))
    fi

    new_version_only="$major.$minor.$patch"
    new_build_version="$new_version_only+$build_number"

    if [ -n "$rc" ]; then
        new_build_version="$new_build_version-rc$rc"
    fi

    echo "$new_build_version" "$new_version_only" "$build_number"
}

update_version_file() {
    local prev_version=$1
    local new_version=$2
    local version_file=$3

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux system
        sed_command="sed -i"

    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS system
        sed_command="sed -i.bak"

    else
        echo "Unsupported operating system: $OSTYPE"
        exit 5
    fi

    # Replace the version in the file using the appropriate sed command
    $sed_command "s/^version: $prev_version$/version: $new_version/" "$version_file"

}
