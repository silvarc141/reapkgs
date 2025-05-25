#!/usr/bin/env -S nu --stdin

# Is it possible to get the final redirect with http get and remove curl dependency?
def get_final_redirect_url [] {
    curl -w "%{url_effective}\n" -I -L -s -S $in -o /dev/null
}

def sanitize_name [] {
    $in 
    | url decode
    | str replace -a '+' 'plus' # replace "+" with "plus" (readability edge-case)
    | str replace -ar '[^[:alnum:]-]' '-' # replace non-alphanumeric characters with dashes
    | str replace -ar '-{2,}' '-' # remove all but one consequtive dashes
    | str replace -ar '^-' '' # remove leading dash
    | str replace -ar '-$' '' # remove following dash
    | str replace -ar '^[^a-zA-Z]' '_$0' # add an underscore if starting with a non-letter
    | str downcase
}

def prefetch_hash [] {
    let url = $in
    let sanitized_name =  $url | path parse | get stem | sanitize_name
    let url_redirected = $url | get_final_redirect_url

    print -e $"Starting prefetching ($url)"
    let hash = nix-prefetch-url $url_redirected --name $sanitized_name e> /dev/null

    if $env.LAST_EXIT_CODE == 0 {
        print -e $"Successfully prefetched ($url)"
        $hash
    } else {
        print -e $"Error prefetching ($url)"
        error make {msg: $"Error prefetching ($url_redirected) \(redirected from ($url)\)"}
    }
}

def extract_package_data [index_name: string] {
    let package = $in
    let type = $package.content.attributes.type
    let category = $package.category
    let relative_parent_directory = get_package_parent_directory_relative_path $index_name $type $category
    {
        name: $package.content.attributes.name,
        description: $package.content.attributes.desc,
        type: $type,
        category: $category,
        relative_parent_directory: $relative_parent_directory
        raw_versions: (
            $package.content.content
            | where tag == version
            | reject tag
        )
    }
}

def extract_links_with_indices [package_index, versions] {
    $versions
    | enumerate
    | each {|v|
        $v.item.content
        | where tag == source
        | first
        | get content
        | get content
        | enumerate
        | each {|link|
            {
                package_index: $package_index,
                version_index: $v.index,
                link: $link.item
            }
        }
    }
    | flatten
}

def compute_hashes_parallel [] {
    $in
    | par-each {|entry|
        {
            package_index: $entry.package_index,
            version_index: $entry.version_index,
            link: $entry.link,
            hash: ($entry.link | prefetch_hash)
        }
    }
}

def build_versions_with_hashes [raw_versions, hashes, package_index] {
    $raw_versions
    | enumerate
    | each {|entry|
        let version_index = $entry.index
        let version_data = $entry.item
        let sources_with_hashes = $hashes
        | where package_index == $package_index and version_index == $version_index
        | first
        | {
            link: ($in.link), 
            hash: ($in.hash),
            relative_path: (get_package_file_relative_path $in.link $in.link)
        }
        {
            name: $version_data.attributes.name,
            author: $version_data.attributes.author,
            time: ($version_data.attributes.time | into datetime),
            files: $sources_with_hashes
        }
    }
    | sort-by time --reverse
}

def get_package_parent_directory_relative_path [
    index_name: string
    type: string
    category: string
] {
    let typeToPath = {
        script: "Scripts",
        effect: "Effects",
        data: "Data",
        extension: "UserPlugins",
        theme: "ColorThemes",
        langpack: "LangPack",
        web-interface: "reaper_www_root",
        project-template: "ProjectTemplates",
        track-template: "TrackTemplates",
        midi-note-names: "MIDINoteNames",
        automation-item: "AutomationItems",
    };

    let typePath = ($typeToPath | get $type)

    if (["script" "effect" "automation-item"] has $type) {
        $"($typePath)/($index_name)/($category)"
    }
    else {
        $typePath
    }
}

def get_package_file_relative_path [
    url: string
    explicit_file_path: string
] {
    if $explicit_file_path == "" { 
        $url | url parse | get path | url decode | path basename 
    } else { 
        $explicit_file_path 
    }
}

def process_reapack_index [] {
    let index_name = $in.attributes.name
    let packages = (
        $in
        | get content
        | where tag == category
        | reject tag
        | flatten
        | rename -c {name: category}
    )

    let extracted_packages = (
        $packages
        | enumerate
        | each {|package|
            let package_data = $package.item | (extract_package_data $index_name)
            let link_entries = extract_links_with_indices $package.index $package_data.raw_versions
            {
                index: $package.index,
                data: $package_data,
                links: $link_entries
            }
        }
    )

    let hashes = $extracted_packages | get links | flatten | compute_hashes_parallel

    $extracted_packages
    | each {|entry|
        {
            name: ($entry.data.name | path parse | get stem | sanitize_name),
            type: $entry.data.type,
            category: $entry.data.category,
            description: $entry.data.description,
            versions: (build_versions_with_hashes $entry.data.raw_versions $hashes $entry.index)
        }
    }
    | move --first name type category description
}

# Takes a ReaPack index URL as input and outputs it's data with prefetched file hashes in JSON
def main [
    --raw (-r) # Treat piped input as a raw xml string
]: string -> string { 
    if $raw { $in | from xml | process_reapack_index | to json } else { http get $in | process_reapack_index | to json }
}
