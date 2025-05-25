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

def extract_links_with_indices [package_index, raw_versions] {
  $raw_versions
  | enumerate
  | each {|raw_version|
      $raw_version.item.content
      | where tag == source
      | each {|file|
          {
              package_index: $package_index,
              version_index: $raw_version.index,
              link: ($file.content.content | first)
          }
      }
  }
  | flatten
}

def reconstruct_versions [raw_versions, hashed_files, package_index] {
    $raw_versions
    | enumerate
    | each {|entry|
        let version_index = $entry.index
        let version_data = $entry.item
        {
            name: $version_data.attributes.name,
            author: $version_data.attributes.author,
            time: ($version_data.attributes.time | into datetime),
            files: ($hashed_files
                | where package_index == $package_index and version_index == $version_index
                | each {|file|
                    let explicit_relative_path = $version_data.attributes | get -i file | default ""
                    {
                        link: ($file.link), 
                        hash: ($file.hash),
                        relative_path: (get_package_file_relative_path $file.link $explicit_relative_path)
                    }
                })
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
    } else {
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

    let processed_packages = (
        $packages
        | enumerate
        | each {|package|
            let package_data = {
                name: ($package.item.content.attributes.name | path parse | get stem | sanitize_name),
                description: $package.item.content.attributes.desc,
                type: $package.item.content.attributes.type,
                category: $package.item.category,
                raw_versions: ($package.item.content.content | where tag == version | reject tag)
            }
            | insert relative_parent_directory (get_package_parent_directory_relative_path $index_name $in.type $in.category)

            let addressed_urls = extract_links_with_indices $package.index $package_data.raw_versions

            {
                index: $package.index,
                data: $package_data,
                links: $addressed_urls
            }
        }
    )

    let hashed_files = $processed_packages | get links | flatten | par-each {|entry|
        {
            package_index: $entry.package_index,
            version_index: $entry.version_index,
            link: $entry.link,
            hash: ($entry.link | prefetch_hash)
        }
    }

    $processed_packages | each {|entry|
        $entry.data 
        | insert versions (reconstruct_versions $entry.data.raw_versions $hashed_files $entry.index)
        | reject raw_versions
    }
    | move --first name type category description
}

# Takes a ReaPack index URL as input and outputs it's data with prefetched file hashes in JSON
def main [
    --raw (-r) # Treat piped input as a raw xml string
]: string -> string { 
    if $raw { $in | from xml | process_reapack_index | to json } else { http get $in | process_reapack_index | to json }
}
