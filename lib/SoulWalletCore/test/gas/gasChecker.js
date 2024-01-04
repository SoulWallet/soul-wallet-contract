'use strict';
import chalk from 'chalk';
import fs from 'fs';
import shell from 'shelljs';

if (!shell.which('forge')) {
    console.log('Sorry, this script requires forge, visit: ' + chalk.blue('https://book.getfoundry.sh/getting-started/installation#using-foundryup'));
    shell.exit(1);
}

shell.exec('forge build', { silent: false });

// run `forge test -vv --match-contract 'GasCheckerTest'`
const result = shell.exec('forge test -vv --match-contract "GasCheckerTest"', { silent: true });
const lines = result.stdout.split('\n');

const map = new Map();

for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.startsWith("  gasChecker\t")) {
        const gasInfo = line.split('\t');
        const name = gasInfo[1].trim();
        const gasUsed = parseInt(gasInfo[2].trim());
        map.set(name, gasUsed);
    }
}

// print gas change
let gasChangeLog = '';
const template = fs.readFileSync('gas.md', 'utf8');
const gasBeforeMap = new Map();
const gasUesdBefore = template.split('\n').slice(4, -1);
for (let i = 0; i < gasUesdBefore.length; i++) {
    const line = gasUesdBefore[i];
    const gasInfo = line.split('|');
    const name = gasInfo[1].trim();
    const gasUsed = parseInt(gasInfo[2].trim());
    gasBeforeMap.set(name, gasUsed);
}


let changedLine = 0;
for (let [name, gas_before] of gasBeforeMap) {
    if (map.has(name)) {
        let gas_after = map.get(name);
        const gas_change = gas_after - gas_before;
        if (gas_change !== 0) {
            changedLine++;
            if (gas_change > 0) {
                gasChangeLog += `🚨 ${name}\t${gas_before} -> ${gas_after}\t${chalk.red('+ ' + gas_change + ' gas')}\n`;
            } else {
                gasChangeLog += `🎉 ${name}\t${gas_before} -> ${gas_after}\t${chalk.green('- ' + gas_change + ' gas')}\n`;
            }
        }
    } else {
        console.log(chalk.red(`!!!!!!!!!!! ${name} is removed`));
    }
}

for (let [name, gas_after] of map) {
    if (!gasBeforeMap.has(name)) {
        console.log(chalk.red(`!!!!!!!!!!! ${name} is added`));
    }
}

console.log(`${chalk.green('Gas Change Log')}\n\nChanged Line:\t${chalk.yellow(changedLine)}\n\n${gasChangeLog}`);

// node test/gas/gasChecker.js --update
if (process.argv[2] === '--update') {
    // write md file
    let md = `# Gas Checker\n\n`;
    md += `| Name | Gas Used |\n`;
    md += `| ---- | -------- |\n`;

    for (let [name, gas_after] of map) {
        md += `| ${name} | ${gas_after} |\n`;
    }

    fs.writeFileSync('gas.md', md);
    console.log(chalk.green('save gas.md success!'));
}


