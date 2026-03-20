#!/usr/bin/env sh

set -e

VERSION=$(cat apworld/uzdoom/VERSION)

cat <<EOF
<!doctype html>
<html>
  <head>
    <meta charset="UTF-8">
    <title>GZDoom APworld packager</title>
    <script src="jszip.min.js"></script>
    <script>
      var generate_enabled = false;
      function updateInfo() {
        let wadname = document.querySelector("#name");
        let button = document.querySelector("#generate");
        let files = document.querySelector("#files");
        let filelist = document.querySelector("#filelist");

        var has_logic = false;
        filelist.innerHTML = "";
        for (file of files.files) {
          has_logic = has_logic || file.name.endsWith(".logic");
          filelist.innerHTML += "- " + file.name + "\n";
        }

        generate_enabled = false;
        if (wadname.value === "") {
          button.value = "⛔ No WAD name entered";
        } else if (files.files.length <= 0) {
          button.value = "⛔ No logic/tuning files selected";
        } else if (!has_logic) {
          button.value = "⛔ No .logic files selected";
        } else {
          button.value = "✓ Generate " + getApworldFileName();
          generate_enabled = true;
        }
      }

      function getWadTitle() {
        return document.querySelector("#name").value;
      }
      function getWadSymbol() {
        return document.querySelector("#name").value.toLowerCase().replaceAll(" ", "_");
      }
      function getApworldName() {
        return "zdoom_" + getWadSymbol();
      }
      function getApworldFileName() {
        return getApworldName() + ".apworld";
      }

      function getFileContents(selector) {
        return document.querySelector(selector).innerText.replaceAll("__WAD__", getWadSymbol());
      }

      function generate() {
        if (!generate_enabled) return;

        let files = document.querySelector("#files");
        let zip = JSZip();

        zip.file(getApworldName() + "/archipelago.json", getFileContents("#manifest_template"));
        zip.file(getApworldName() + "/__init__.py", getFileContents("#init_template"));
        zip.file(getApworldName() + "/Options.py", getFileContents("#options_template"));
        zip.file(getApworldName() + "/VERSION", "$VERSION");

        let futures = [];
        for (f of files.files) {
          let file = f; // Introduce a new binding so each closure gets a different one
          if (file.name.endsWith(".logic")) {
            futures.push(file.bytes().then((bytes) => zip.file(getApworldName() + "/logic/" + file.name, bytes)));
          } else {
            futures.push(file.bytes().then((bytes) => zip.file(getApworldName() + "/tuning/" + file.name, bytes)));
          }
        }
        Promise.allSettled(futures)
          .then(() => zip.generateAsync({
            type: "blob", platform: "UNIX", compression: "DEFLATE"
          }))
          .then((blob) => {
            let url = URL.createObjectURL(blob);
            let a = document.querySelector("#download");
            a.href = url;
            a.download = getApworldFileName();
            console.log("Download ready:", blob);
            window.setTimeout(() => URL.revokeObjectURL(url), 30*1000);
            a.click();
          });
      }
    </script>
  </head>
  <body>
    <p>⚠️ This is the generator for the <b>unstable</b> version of the apworld ($VERSION). <a href="apworld-generator-$STABLE.html">Click here for latest stable ($STABLE).</a></p>
    <!--
    <p>🛈 This is the generator for version $STABLE of the apworld.</p>
    -->
    <label for="name">WAD name:</label>
    <input type="text" id="name" name="name" required oninput="updateInfo();"/>
    <br/>
    <label for="files">Logic/tuning files:</label>
    <input type="file" id="files" name="files" required multiple accept=".logic,.tuning" oninput="updateInfo();"/>
    <pre id="filelist"></pre>
    <br/>
    <input type="button" id="generate" value="⛔ No WAD name entered" onclick="generate();"/>

    <div style="display:none">
      <a id="download"></a>
      <pre id="manifest_template">
{
    "game": "GZDoom (__WAD__)",
    "version": 7,
    "compatible_version":7,
    "authors": ["ToxicFrog's robot army"]
}
      </pre>
      <pre id="init_template">
$(cat wads/__template__/__init__.py)
      </pre>
      <pre id="options_template">
$(cat wads/__template__/Options.py)
      </pre>
    </div>
  </body>
</html>
EOF
