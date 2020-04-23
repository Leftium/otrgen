{Command, flags} = require '@oclif/command'
TurndownService = require('turndown')

fs = require('fs').promises

tsRE = /(?<h>\d):(?<m>\d\d):(?<s>\d\d)\.(?<ms>\d\d\d)/
ttmlRE = /^<p begin="(?<ts1>[\d:.]*)" end="(?<ts2>[\d:.]*)" style="s2">(?<text>.*?)<\/p>$/
mdtsRE = /<t ms=(?<ms>\d+)>(?<m>\d\d):(?<s>\d\d)<\/t>/

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


html2Markdown = (html) ->
    turndownService = new TurndownService()

    turndownService.escape = (text) -> text

    turndownService.addRule 'p', options =
        filter: 'p'
        replacement: (content, node, options) ->
            # Replace non-breaking spaces with space
            content = content.replace /\u00a0/g, ' '
            "\n#{content}"

    turndownService.addRule 'timestamp', options =
        filter: 'span'
        replacement: (content, node, options) ->
            if node.className is 'timestamp'
                timestamp = node.dataset.timestamp
                ms = timestamp.split('.').pop()
                return "<t ms=#{ms}>#{content}</t>"
            else
                return content

    markdown = turndownService.turndown(html)

    lines = markdown.split '\n'
    results = []

    # We want blank lines between notes and timestamps, but
    # keep consecutive timestamps to be tightly packed.
    for line in lines
        if line.match /^<t ms=/
            line = "\n#{line}<br>"
        else
            line = line.replace /\u00a0/g, ' '
        results.push line

    markdown = results.join '\n'
    # Remove extra newlines between consecutive timestamps.
    markdown = markdown.replace /<br>\n\n/g, '<br>\n'

markdown2Html = (markdown) ->
    lines = markdown.split '\n'

    results = []
    for line in lines
        if matches = line.match mdtsRE
            groups = matches.groups

            # Convert timestamp to seconds
            m  = parseInt groups.m,  10
            s  = parseInt groups.s,  10
            ms = parseInt groups.ms, 10
            seconds = m*60 + s + ms/1000


            line = line.replace mdtsRE, """
                <span class="timestamp" data-timestamp="#{seconds}">#{groups.m}:#{groups.s}</span>
            """
        else
            # Ensure spacing preserved with non-breaking spaces.
            line = line.replace /[ ]/g, '\u00a0'
            line = "#{line}<br/>"
        results.push line


    html = results.join '\n'


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

        switch inputFormat
            when 'otr', 'html', 'htm'
                if inputFormat is 'otr'
                    otr = JSON.parse text
                    html = otr.text
                else
                    html = text

                switch outputFormat
                    when 'html'
                        @log html
                    when 'md'
                        @log html2Markdown html
                    else
                        @error "Unsupported output format #{outputFormat}."
            when 'md'
                html = markdown2Html text
                otr =
                    text: html

                switch outputFormat
                    when 'html'
                        @log html
                    when 'otr'
                        @log JSON.stringify(otr, 3)
                    else
                        @error "Unsupported output format #{outputFormat}."

            when 'ttml', 'sbv'
                lines = text.split /\r?\n/
                # Check for and convert TTML format to SBV
                if (inputFormat is 'ttml') or (lines[1].match /tt xml/)
                    lines = ttml2sbv lines

                resultsHtml = []
                while lines.length
                    {ts, text} = parseBlock lines
                    resultsHtml.push "#{otrTimestamp ts} #{text} <br/>"


                html = resultsHtml.join '\n'
                otr =
                    text: html

                switch outputFormat
                    when 'html'
                        @log html
                    when 'otr'
                        @log JSON.stringify(otr, 3)
                    when 'md'
                        @log html2Markdown html
                    else
                        @error "Unsupported output format #{outputFormat}."
            else
                @error "Unsupported input format #{inputFormat}."



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
