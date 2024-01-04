const fs = require("fs");
const os = require("os");
const path = require("path");

const envFilePath = path.resolve(__dirname, "..", "..", ".env_backend");

const readEnvVars = () => fs.readFileSync(envFilePath, "utf-8").split(os.EOL);

const writeToEnv = (key, value) => {
  const envVars = readEnvVars();
  const targetLine = envVars.find((line) => line.split("=")[0] === key);
  if (targetLine !== undefined) {
    const targetLineIndex = envVars.indexOf(targetLine);
    if (value.startsWith("0x")) {
      envVars.splice(targetLineIndex, 1, `${key}=${value}`);
    } else {
      envVars.splice(targetLineIndex, 1, `${key}=${value}`);
    }
  } else {
    if (value.startsWith("0x")) {
      envVars.push(`${key}=${value}`);
    } else {
      envVars.push(`${key}="${value}"`);
    }
  }
  fs.writeFileSync(envFilePath, envVars.join(os.EOL));
};
var arguments = process.argv.slice(2);
if (arguments.length != 2) {
  console.log("wrong number of arguments");
  process.exit(1);
}
writeToEnv(arguments[0], arguments[1]);
