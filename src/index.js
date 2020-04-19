const {Command, flags} = require('@oclif/command')

class OtrgenCommand extends Command {
  async run() {
    const {flags} = this.parse(OtrgenCommand)
    const name = flags.name || 'world'
    this.log(`hello ${name} from .\\src\\index.js`)
  }
}

OtrgenCommand.description = `Describe the command here
...
Extra documentation goes here
`

OtrgenCommand.flags = {
  // add --version flag to show CLI version
  version: flags.version({char: 'v'}),
  // add --help flag to show CLI version
  help: flags.help({char: 'h'}),
  name: flags.string({char: 'n', description: 'name to print'}),
}

module.exports = OtrgenCommand
