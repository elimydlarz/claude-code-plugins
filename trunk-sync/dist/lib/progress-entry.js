import { PROGRESS_USAGE, recordProgress } from "./progress.js";
function main() {
    const args = process.argv.slice(2);
    if (args.includes("--help") || args.includes("-h")) {
        console.log(PROGRESS_USAGE);
        return;
    }
    try {
        console.log(recordProgress(args, process.cwd()));
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        console.error(message);
        process.exit(1);
    }
}
main();
