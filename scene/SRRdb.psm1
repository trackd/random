﻿function Get-SRRdb {
    <#
    .SYNOPSIS
    SRRdb API Powershell function.
    .NOTES
    fun learning excercise.
    .LINK
    https://api.srrdb.com/v1/docs
    .LINK
    https://www.srrdb.com/help
    .PARAMETER imdbNumber
    Search with imdb number, returns releases.
    .PARAMETER GetIMDB
    Search with release, returns imdb info.
    .PARAMETER Details
    return information about a single release
    .PARAMETER NFO
    list nfo files and download link for specified release
    .PARAMETER ShowNFO
    only works with NFO param, will output the NFO to screen.
    .PARAMETER Search
    Search
    .PARAMETER Feed
    New release feed, supports -Include and -Exclude
    .PARAMETER Titles
    Title list
    .PARAMETER Raw
    Raw api output
    .PARAMETER Include
    Regex Filter to include, match ANY
    only applies to Feed
    -Include '2160p|Bluray'
    .PARAMETER Exclude
    Regex Filter to exclude, match ANY
    only applies to Feed
    -Exclude 'German|French'
    .PARAMETER DisableFilters
    disables default filters if set.
    .EXAMPLE
    Get-SRRdb -Feed -Exclude 'German|French' -Include '2160p|Bluray'
    # Below will grab feed and exclude anything matching German or French, and add anything matching 2160p or bluray (both not required)
    .EXAMPLE
    Get-SRRdb -imdbNumber 1630029
    # Searches for all releases for Avatar, uses imdb ID.
    .EXAMPLE
    Get-SRRdb -GetIMDB releasename
    # Will get imdb Title, rating, votes for release.
    .EXAMPLE
    Get-SRRdb -NFO releasename
    # nfo will check if SRR has a copy of the NFO and show you the link to the file.
    .EXAMPLE
    Get-SRRDb -NFO -ShowNFO releasename
    # Same as with NFO but will output the NFO to screen as well.
    .EXAMPLE
    Get-SRRdb -Details releasename
    # Get Details for a release, will show all files related to it.
    .EXAMPLE
    Get-SRRdb -Titles
    # Titles from api
    .EXAMPLE
    Get-SRRdb -Feed -raw
    # Raw api output, useful for debug, works on all params.
    .EXAMPLE
    Get-SRRdb -Search 'Harry Potter And The Deathly Hallows'
    # Search
    .EXAMPLE
    Get-SRRDb -GetIMDB (Get-SRRdb -imdbNumber 1630029)[0].release
    .Notes
    defaults
    add to $profile for keeping your include/exclude
    my filters:
	$PSDefaultParameterValues['Get-SRRdb:Include'] = 'x264|x265|h264|h265|bluray|1080p|720p|2160p'
	$PSDefaultParameterValues['Get-SRRdb:Exclude'] = 'German|Norwegian|XXX|Danish|French|Italian|\-DDC|SUBBED|DUBBED'
    add -Verbose to your command to troubleshoot filters
    #>
    [CmdletBinding(DefaultParameterSetName = 'Feed')]
    param (
        [Parameter(ParameterSetName = 'Search', Mandatory, HelpMessage = 'Search', Position = 0)]
        [String]
        $Search,
        [Parameter(ParameterSetName = 'ByIMDB', Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'Search for releases matching imdb number')]
        [Alias('imdb')]
        [String]
        $imdbNumber,
        [Parameter(ParameterSetName = 'ByRelease', Mandatory, ValueFromPipelineByPropertyName, HelpMessage = 'Search with a release, returns imdb info')]
        [Alias('BaseName')]
        [String]
        $GetIMDB,
        [Parameter(ParameterSetName = 'Details', Mandatory, HelpMessage = 'return information about a single release')]
        [String]
        $Details,
        [Parameter(ParameterSetName = 'NFO', Mandatory, HelpMessage = 'list nfo files and download link for specified release')]
        [String]
        $NFO,
        [Parameter(ParameterSetName = 'NFO', HelpMessage = 'Show NFO')]
        [Switch]
        $ShowNFO,
        [Parameter(ParameterSetName = 'Feed', HelpMessage = 'New release feed')]
        [Switch]
        $Feed,
        [Parameter(ParameterSetName = 'Feed', HelpMessage = 'Include filter (Regex) for output results')]
        #[Parameter(ParameterSetName = 'Search')]
        #  TODO: should be nullable to override PSDefaultParameterValues, without doing [-Include '']
        [AllowEmptyString()]
        [AllowNull()]
        [String]
        # might want to set the default here
        $Include,
        [Parameter(ParameterSetName = 'Feed', HelpMessage = 'Exclude filter (Regex) for output results')]
        #[Parameter(ParameterSetName = 'Search')]
        #  TODO: should be nullable to override PSDefaultParameterValues, without doing [-Exclude '']
        [AllowEmptyString()]
        [AllowNull()]
        [String]
        # might want to set the default here
        $Exclude,
        [Parameter(ParameterSetName = 'Feed', HelpMessage = 'Disable filters if using PSDefaultParameterValues')]
        [Switch]
        $DisableFilters,
        [Parameter(ParameterSetName = 'Titles', Mandatory, HelpMessage = 'Title feed')]
        [Switch]
        $Titles,
        [Parameter(DontShow)]
        [Switch]
        $Raw
    )
    begin {
        Write-Verbose "Module: $($ExecutionContext.SessionState.Module.Name) Command: $($MyInvocation.MyCommand.Name) ParameterSetName: $($PSCmdlet.ParameterSetName) Param: $($PSBoundParameters.GetEnumerator())"
        if (-Not $feed -And $PSCmdlet.ParameterSetName -eq 'Feed') {
            #default to feed api if no input is given.
            $feed = $true
        }
        if ($DisableFilters) {
            $Exclude = $null
            $Include = $null
        }
    }
    process {
        #setup url based on input
        $baseUrl = 'https://api.srrdb.com'
        if ($Search) {
            $url = "$baseUrl/v1/search/"
            $query = $search
        } elseif ($imdbNumber) {
            $url = "$baseUrl/v1/search/imdb:"
            $query = $imdbNumber
        } elseif ($GetIMDB) {
            $url = "$baseUrl/v1/imdb/"
            $query = $GetIMDB
        } elseif ($nfo) {
            $url = "$baseUrl/v1/nfo/"
            $query = $NFO
        } elseif ($details) {
            $url = "$baseUrl/v1/details/"
            $query = $details
        } elseif ($feed) {
            $url = 'https://www.srrdb.com/feed/srrs'
        } elseif ($Titles) {
            $url = 'https://www.srrdb.com/feed/titles'
        }
        try {
            if ($url -match 'imdb:') {
                # TODO: cleanup just match the numbers instead.
                $imdbquery = $query -replace 'https://www.imdb.com/title/|https://imdb.com/title/|imdb.com/title/' -replace ' ','/'
                $request = $url + $imdbquery
            } elseif ($Titles -Or $feed) {
                #no query to append
                $request = $url
            } else {
                if ($query -match ' ') {
                    $query = $query -replace ' ','/'
                }
                $request = $url + $query
            }
            #send call
            Write-Verbose "Command: $($MyInvocation.MyCommand.Name), url for api call: $request"
            $response = Invoke-RestMethod -Uri $request
            if ($raw) {
                #if raw output was requested (troubleshooting)
                Write-Verbose "Command: $($MyInvocation.MyCommand.Name), raw output"
                return $response
            } else {
                if ($response.resultsCount -eq 0) {
                    return "Query: $($response.query) Results: $($response.resultsCount)"
                }
                #loop through response
                $results = foreach ($object in $response) {
                    if ($feed) {
                        if (($object.Title -match $exclude) -and ($exclude.Length -gt 0)) {
                            Write-Verbose "Exclude: $($object.Title) match: ""$($matches.Values)"" in exclude list: $($exclude)"
                            continue
                        }
                        if ($object.Title -match $include) {
                            #looks like $null also matches, would be more explicit to define with -Not $Include..
                            #if (($object.Title -match $include) -or (-Not $Include)) {
                            Write-Verbose "Include: $($object.Title) match: ""$($matches.Values)"" in include list: $($include)"
                            $published = Get-Date $object.pubDate -Format 'yyyy-MM-dd MM:hh'
                            # $object.description -replace '<[^>]+>' -replace '(?m)^\s+' -split '\r\n|\n'
                            $cleandescription = $object.description.'#cdata-section' -replace '<[^>]+>' -replace '(?m)^\s+' -split '\n'
                            #$imdbnum = (Select-String -Pattern '(http://www.imdb.com/title/tt)(.*)' -InputObject $cleandescription).matches.value
                            [PSCustomObject]@{
                                Title      = $object.Title
                                #guid        = $object.guid
                                #description = $object.description.'#cdata-section'
                                #description = $cleandescription
                                #imdb        = $imdbnum
                                Published  = $published
                                Group      = $cleandescription[4]
                                UploadDate = $cleandescription[6]
                                NFO        = $cleandescription[8]
                                SRS        = $cleandescription[10]
                                imdb       = $cleandescription[12]
                                #Published = $object.pubDate
                                link       = $object.link
                            }
                        }
                    } elseif ($NFO) {
                        Write-Verbose "Command: $($MyInvocation.MyCommand.Name), NFO"
                        $NFOitem = [PsCustomObject]@{
                            #Request  = $NFO
                            Release  = $($object.release)
                            Filename = $($object.nfo)
                            Link     = $($object.nfolink)
                        }
                        if ($ShowNFO -And $object.nfolink) {
                            $NFODownload = try { Invoke-RestMethod -Uri $($object.nfolink) } catch { 'error downloading file' }
                            $NFOitem | Add-Member -MemberType NoteProperty -Name 'NFO' -Value "$($NFODownload)"
                        }
                        #TODO: remove format-list & fix so it outputs as a list because values are too wide for console.
                        $NFOitem | Format-List
                    } elseif ($imdbNumber -or $Search) {
                        # category:x264 ? / category:tv
                        Write-Verbose "Command: $($MyInvocation.MyCommand.Name), Search: $($object.query) Results: $($object.resultsCount)"
                        $TvRegex = '(?<Title>^.*?)\.(?:(?<Year>(19|20)\d{2})\.)?S(?<Season>\d{2})E(?<Episode>\d{2}).*?(?:\.(?<Update>REPACK\.PROPER|PROPER\.REPACK|REAL\.PROPER|REAL|PROPER|REPACK))?\.(?<Quality>\d{3,4}p).*?\.(?<Source>WEB\-DL|WEBRip|WEB|Bluray|HDTV)\.(?<Codec>x264|x265|h264|h265)\-(?<Group>.*$)'
                        # needs more work on the MovieRegex..
                        # $MoviesRegex = '(?<Title>^.*?)\.(?:(?<Year>(19|20)\d{2})\.)?.*?(?:\.(?<Update>REPACK\.PROPER|PROPER\.REPACK|REAL\.PROPER|REAL|PROPER|REPACK))?\.(?<Quality>\d{3,4}p).*?\.(?<Source>WEB\-DL|WEBRip|WEB|Bluray|HDTV)\.(?<Codec>x264|x265|h264|h265)\-(?<Group>.*$)'
                        foreach ($item in $object.results) {
                            if ($item.release -match $TvRegex) {
                                [PsCustomObject]@{
                                    Title   = $matches.Title -replace '\.',' '
                                    Year    = $matches.Year
                                    Season  = $matches.Season
                                    Episode = $matches.Episode
                                    Update  = $matches.Update
                                    Quality = $matches.Quality
                                    Codec   = $matches.Codec
                                    Group   = $matches.Group
                                    release = $item.release
                                    date    = $item.Date
                                    NFO     = $item.hasNFO
                                    SRS     = $item.hasSRS
                                }
                            }
                            # elseif ($item.release -match $MoviesRegex) {
                            #     [PsCustomObject]@{
                            #         Title   = $matches.Title -replace '\.',' '
                            #         Year    = $matches.Year
                            #         Update  = $matches.Update
                            #         Quality = $matches.Quality
                            #         Codec   = $matches.Codec
                            #         Group   = $matches.Group
                            #         release = $item.release
                            #         date    = $item.Date
                            #         NFO     = $item.hasNFO
                            #         SRS     = $item.hasSRS
                            #     }
                            else {
                                [PsCustomObject]@{
                                    # Title   = ''
                                    # Year    = ''
                                    # Season  = ''
                                    # Episode = ''
                                    # Update  = ''
                                    # Quality = ''
                                    # Codec   = ''
                                    # Group   = ''
                                    release = $item.release
                                    date    = $item.Date
                                    NFO     = $item.hasNFO
                                    SRS     = $item.hasSRS
                                }
                            }
                        }
                    } elseif ($Titles) {
                        Write-Verbose "Command: $($MyInvocation.MyCommand.Name), Titles"
                        if ($object.title) {
                            $published = Get-Date $object.pubDate -Format 'yyyy-MM-dd MM:hh'
                            [PsCustomObject]@{
                                Title = $object.title
                                date  = $published
                                link  = $object.link
                            }
                        }
                    } elseif ($GetIMDB) {
                        Write-Verbose "Command: $($MyInvocation.MyCommand.Name), Found IMDB for release: $($object.query) imdbID:$($object.releases.imdb) imdbTitle:$($object.releases.title)"
                        [PsCustomObject]@{
                            title  = $object.releases.title
                            imdb   = $object.releases.imdb
                            rating = $object.releases.rating
                            votes  = $object.releases.votes
                        }
                    } elseif ($Details) {
                        Write-Verbose "Command: $($MyInvocation.MyCommand.Name), Details: $($object.Name)"
                        # Write-Verbose "Command: $($MyInvocation.MyCommand.Name), unpacked crc info: $($object.'archived-files')"
                        foreach ($item in $object.files) {
                            [PsCustomObject]@{
                                Name = $item.name
                                Size = $item.Size
                                crc  = $item.crc
                            }
                        }
                    } else {
                        Write-Warning 'something weird happend, nothing matched. returning input untouched.'
                        $object
                    }
                }
            }
        } catch {
            throw $_
        }
    }
    end {
        $results
    }
}

function Search-SRRdb {
    <#
    .SYNOPSIS
    Search helper with all params that api supports.
    .LINK
    https://www.srrdb.com/help#api
    .NOTES
    switched from ArgumentCompletions to ValidateSet to support ps 5.1
    .EXAMPLE
    Search-SRRdb -imdb 0289830
    $PSDefaultParameterValues['Search-SRRdb:Include'] = 'x264|x265|h264|h265|bluray|1080p|720p|2160p'
	$PSDefaultParameterValues['Search-SRRdb:Exclude'] = 'German|Norwegian|XXX|Danish|French|Italian|\-DDC'
    #>
    param(
        [String]
        $Search,
        [String]
        $group,
        [String]
        $date,
        [string]
        $r,
        # [ArgumentCompletions('yes','no')]
        [ValidateSet('yes','no')]
        [string]
        $nfo,
        # [ArgumentCompletions('yes','no')]
        [ValidateSet('yes','no','broken')]
        [string]
        $srs,
        # [ArgumentCompletions('yes','no')]
        [ValidateSet('yes','no')]
        [string]
        $foreign,
        # [ArgumentCompletions('yes','no')]
        [ValidateSet('yes','no')]
        [string]
        $confirmed,
        [string]
        $rarhash,
        # [ArgumentCompletions('unknown','tv','xvid','x264','dvdr','xxx','pc','ngc','wii','3ds','nds','xbox360','xbox','ps3','psp','complete+bluray','wmv','subpack','apps','game','flac','mp3','mvid','wiiu','ps4','xboxone','psv','nsw','gba','gbc','gizmondo','gp32','ngage','ngp','tapwave+zodiac','ws','ebook','scene+notice','n64','psx','ps2','dc','cover','ogg','remux')]
        [ValidateSet('unknown','tv','xvid','x264','dvdr','xxx','pc','ngc','wii','3ds','nds','xbox360','xbox','ps3','psp','complete+bluray','wmv','subpack','apps','game','flac','mp3','mvid','wiiu','ps4','xboxone','psv','nsw','gba','gbc','gizmondo','gp32','ngage','ngp','tapwave+zodiac','ws','ebook','scene+notice','n64','psx','ps2','dc','cover','ogg','remux')]
        [string]
        $category,
        [string]
        $imdb,
        [string]
        $start,
        [string]
        $genre,
        [string]
        $language,
        [string]
        $country,
        [string]
        ${archive-crc},
        [string]
        $isdbhash,
        # [ArgumentCompletions('yes','no')]
        [ValidateSet('yes','no')]
        [string]
        $lower,
        [string]
        $endorstartwithdot,
        [string]
        $compressed,
        [int]
        $skip,
        [int]
        $skipr ,
        [string]
        ${store-real-filename},
        [string]
        ${store-real-crc},
        [string]
        $word,
        # [ArgumentCompletions('date-asc','date-dsc')]
        [ValidateSet('date-asc','date-dsc')]
        [string]
        $order,
        [String]
        $Include,
        [String]
        $Exclude
    )
    Write-Verbose "Module: $($ExecutionContext.SessionState.Module.Name) Command: $($MyInvocation.MyCommand.Name) Param: $($PSBoundParameters.GetEnumerator())"
    if ($MyInvocation.BoundParameters.count -eq 0) { return 'need something to search for' }
    # Ignore the Default parameters (-Verbose, -Debug etc.) and our -Exclude -Include from querybuilder.
    [string[]]$IgnoredParams = @(
        # no longer need below as I'm not using cmdletbindiing() or parameter()
        # [System.Management.Automation.Internal.CommonParameters].DeclaredProperties.name
        'Exclude'
        'Include'
    )
    $query = [System.Text.StringBuilder]::new()
    # diff with $MyInvocation.BoundParameters.keys ?
    # try with foreach @PSBoundParameters
    foreach ($key in $PSBoundParameters.Keys) {
        if ($key -notin $IgnoredParams) {
            if ($key -eq 'Search') {
                # probably not neccessary to insert the search param first, but makes it easier to read.
                [void]$query.insert(0,"$($PSBoundParameters.Item($key) -replace ' ','/')/")
            } else {
                [void]$query.append("$($key):$($PSBoundParameters.Item($key))/")
            }
        }
    }
    $StringReady = $query.ToString().TrimEnd('/')
    Write-Verbose "Command: $($MyInvocation.MyCommand.Name), Stringbuilder: $($StringReady)"
    if ($StringReady) {
        $results = Get-SRRdb -Search "$($StringReady)"
        foreach ($object in $results) {
            if (($object.Release -match $exclude) -and ($exclude.Length -gt 0)) {
                Write-Verbose "Exclude: $($object.Release) match: ""$($matches.Values)"" in exclude list: $($exclude)"
                continue
            }
            if ($object.Release -match $include) {
                Write-Verbose "Include: $($object.Release) match: ""$($matches.Values)"" in Include list: $($include)"
                $object
            }
        }
    } else { throw 'not able to build a string from input.' }
}

function Get-SRRSearchAlternative {
    <#
    .SYNOPSIS
    helper function for getting alternative releases.
    combines search for getting an imdb # from $alternative (release name) and looking up alternative releases
    #>
    param(
        [string]
        $Alternative
    )
    Write-Verbose "Command: $($MyInvocation.MyCommand.Name) Param: $($PSBoundParameters.GetEnumerator())"
    $source = Get-SRRdb -GetIMDB $Alternative
    Search-SRR -imdb $source.imdb
}
Function Get-SRRTvToday {
    <#
    sugar
    #>
    Search-SRRdb -foreign no -category Tv -date (Get-Date -Format 'yyyy-MM-dd') -Exclude '(19|20)\d{2}\.\d{2}\.\d{2}|German|Norwegian|XXX|Danish|French|Italian|\-DDC|\(|\)' -Include '1080p|720p' | Sort-Object -Property date
}
Function Get-SRRMoviesToday {
    <#
    sugar
    #>
    Search-SRRdb -Search 1080p -foreign no -category x264 -date (Get-Date -Format 'yyyy-MM-dd') -Exclude '(19|20)\d{2}\.\d{2}\.\d{2}|German|Norwegian|XXX|Danish|French|Italian|\-DDC|\-CBFM$|HDTV|\(|\)' | Sort-Object -Property date
}
Function Get-SRRTvAutomation {
    <#
    sugar for automation
    #>
    Write-Verbose "Command: $($MyInvocation.MyCommand.Name) Param: $($PSBoundParameters.GetEnumerator())"
    $TvShows = Search-SRRdb -foreign no -category Tv -date (Get-Date -Format 'yyyy-MM-dd') -Exclude '(19|20)\d{2}\.\d{2}\.\d{2}|German|Norwegian|XXX|Danish|French|Italian|\-DDC|\(|\)'
    $object = foreach ($rls in $TvShows) {
        $show = $rls.title -replace ' ','.'
        [PsCustomObject]@{
            Title   = $rls.Title
            TvShow  = $show
            Season  = $rls.Season
            Episode = $rls.Episode
            Search  = "$show S$($rls.Season)E$($rls.Episode)"
            #release = $item.release
            Date    = $rls.Date
            Source  = 'SRRDb'
        }
    }
    $object | Sort-Object -Property Search -Unique
}
