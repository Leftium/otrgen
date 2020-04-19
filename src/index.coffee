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

    html =  "#{otrStartTs} #{text} <br />"




class OtrgenCommand extends Command
    run: ->
        {args} = @parse OtrgenCommand

        # Show usage if no input file given.
        if args.inputFile is ''
            @_help()
            @exit 0

        text = await fs.readFile args.inputFile, 'utf8'

        lines = text.split /\r?\n/

        # Check for and convert TTML format to SBV
        if lines[1].match /tt xml/
            lines = ttml2sbv lines

        results = []
        while lines.length
            results.push parseBlock lines


        html = results.join '\n'

        otr =
            text: html

        otrString = JSON.stringify otr, 4

        @log otrString



OtrgenCommand.args = [
    arg =
        name: 'inputFile'
        required: false
        default: ''
]

OtrgenCommand.description = """Generate oTranscribe OTR files from TTML/SBV.
Converts TTML/SBV files to OTR format ready for import into oTranscribe.
Get YouTube TTML files with `youtube-dl --write-auto-sub --sub-format ttml [YOUTUBE URL]`.
"""

OtrgenCommand.flags =
    # add --version flag to show CLI version
    version: flags.version {char: 'v'}
    # add --help flag to show CLI version
    help: flags.help {char: 'h'}


module.exports = OtrgenCommand
