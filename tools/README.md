[//]: <> (Need a Markdown viewer? Check out https://markdownlivepreview.com/ or navigate to the `tools` folder on the GitHub repository)

# Monarchy Law Auto Replacer

The **Monarchy Law Auto Replacer** (MLAR) is a Lua 5.4 script intended to parse all relevant files from the Victoria 3 game files, search for any instance of a `has_law = law_type:law_monarchy`, and replace it with a scripted trigger defined by RRK to allow Crowned Republics to count as a monarchy for most content areas.

## Generating files

Windows users can execute `run_generator.bat` and the script will be run for you with no further input necessary. No external software is required in order to run MLAR.

MacOS and Linux users should procure a Lua 5.4 interpreter before using MLAR. The Windows one is from LuaBinaries. They also provide Unix binaries, and they can be accessed at https://luabinaries.sourceforge.net/. Execute `monarchy_law_auto_replacer.lua` to run MLAR.

The script expects one argument, and that is the path to your Victoria 3 directory (i.e., the one with the folders `binaries`, `clausewitz`, `game`, etc.). Please be mindful of spaces in your filepath; you may need to use quotation marks to input it correctly. Also be mindful of EXCLUDING any trailing [back]slashes, as that can mess with detecting whether the correct directory has been specified or not.

Generated files will be placed in a subdirectory named `generated`. If this subdirectory does not exist yet, MLAR will attempt to create it.  Windows users using the provided script to execute MLAR will see outputs copied to a `generator.log` file. Subsequent executions of MLAR will *append* messages to the end of the log file - you are responsible for deleting the log file on your own if it becomes too large.

## Exceptions

The following is a list of directories or specific files whose auto-generated counterpart should NOT be used or needs manual tweaking due to checks for RRK Crowned Republics being undesirable:

* `common/achievements`
* `common/ai_strategies`
* `common/government_types`
  * Except for `01_colonial_administrations.txt`
* `common/history`
* `common/journal_entries`, but only the following:
  * `00_autocracy.txt`
* `common/on_actions`, but only the following:
  * `00_code_on_actions.txt`
    * Put normal law check back in `on_new_ruler` for regency-related content
    * Put normal law check back in `on_law_enactment_started` for Stamp Out Monarchism-related content
* `common/parties`
  * Nothing wrong on a design level, but this is a compatibility nuke, so we will not touch them
* `common/political_movements`
  * Also a compatibility nuke
* `events/iberia_events/regency_events.txt`
* `events/law_events`
* `events/1848.txt`

## Export Notes

* Filename prefix changes to account for break from numeric prefixes:
  * `common/character_templates` - Use `i!_` or later-loading prefix
  * `common/decisions` - Use `l!_` or later-loading prefix
  * `common/script_values` - Use `j!_` or later-loading prefix
