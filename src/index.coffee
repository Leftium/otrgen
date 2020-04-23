{Command, flags} = require '@oclif/command'

fs = require('fs').promises

tsRE = /(?<h>\d):(?<m>\d\d):(?<s>\d\d)\.(?<ms>\d\d\d)/
ttmlRE = /^<p begin="(?<ts1>[\d:.]*)" end="(?<ts2>[\d:.]*)" style="s2">(?<text>.*?)<\/p>$/

decodeEntities = (encodedString) ->
    encodedString.replace /&#(\d+);/gi, (match, numStr) ->
        String.fromCharCode parseInt(numStr, 10)

otrTimestamp = (timestamp) ->
    matches = timestamp.match tsRE
    groups = matches.groups

    # Convert timestamp to seconds
    h  = parseInt groups.h,  10
    m  = parseInt groups.m,  10
    s  = parseInt groups.s,  10
    ms = parseInt groups.ms, 10
    seconds = h*3600 + m*60 + s + ms/1000

    html = """
        <span class="timestamp" data-timestamp="#{seconds}">#{groups.m}:#{groups.s}</span>
    """


markdownTimestamp = (timestamp) ->
    matches = timestamp.match tsRE
    groups = matches.groups

    markdown = """
        <t ms=#{groups.ms}>#{groups.m}:#{groups.s}</t>
    """


ttml2sbv = (lines) ->
    results = []

    for line in lines
        matches = line.match ttmlRE

        if matches
            groups = matches.groups
            results.push "#{groups.ts1}, #{groups.ts2}"
            results.push "#{decodeEntities groups.text}"
            results.push ""

    results

parseBlock = (lines) ->
    timestamps = lines.shift()
    text = lines.shift()
    lines.shift()

    if not timestamps or not text then return


    [startTs, endTs] = timestamps.split ','

    otrStartTs = otrTimestamp startTs

    result =
        ts: startTs
        text: text


class OtrgenCommand extends Command
    run: ->
        {flags, args} = @parse OtrgenCommand

        # Show usage if no input file given.
        if args.inputFile is ''
            @_help()
            @exit 0

        inputFormat = args.inputFile.split('.').pop().toLowerCase()

        outputFormat = flags.format.toLowerCase()
        if outputFormat is 'otr' and inputFormat is 'otr'
            outputFormat = 'md'
        text = await fs.readFile args.inputFile, 'utf8'

        if inputFormat in ['otr', 'html', 'htm']
            if inputFormat is 'otr'
                otr = JSON.parse text
                html = otr.text
            else
                html = text

            switch outputFormat
                when 'html'
                    @log html
                else
                    @error "Unsupported output format #{outputFormat}."
        else
            lines = text.split /\r?\n/
            # Check for and convert TTML format to SBV
            if (inputFormat is 'ttml') or (lines[1].match /tt xml/)
                lines = ttml2sbv lines

            resultsHtml = []
            resultsMarkdown = []
            while lines.length
                {ts, text} = parseBlock lines
                resultsHtml.push "#{otrTimestamp ts} #{text} <br/>"
                resultsMarkdown.push "#{markdownTimestamp ts} #{text} <br/>"

            markdown = resultsMarkdown.join '\n'
            html = resultsHtml.join '\n'
            otr =
                text: html

            switch outputFormat
                when 'html'
                    @log html
                when 'otr'
                    @log otr
                when 'md'
                    @log markdown
                else
                    @error "Unknown output format #{outputFormat}."



OtrgenCommand.description = """Generate oTranscribe OTR files from TTML/SBV.
Converts TTML/SBV files to OTR format ready for import into oTranscribe.
Get YouTube TTML files with `youtube-dl --write-auto-sub --sub-format ttml [YOUTUBE URL]`.
"""

OtrgenCommand.args = [
    arg =
        name: 'inputFile'
        required: false
        default: ''
]

OtrgenCommand.flags =
    # add --version flag to show CLI version
    version: flags.version {char: 'v'}
    # add --help flag to show CLI version
    help: flags.help {char: 'h'}
    format: flags.string options =
        char: 'f'
        description: 'Output format. (Defaults MD if input file is already OTR.)'
        default: 'otr'



module.exports = OtrgenCommand
