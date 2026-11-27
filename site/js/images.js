//////////////////////////////////////////////////////////////////////
//
// images.js
// JavaScript runtime code to manipulate images.
// Copyright (c) 2026 Bill St. Clair <billstclair@gmail.com>
// Some rights reserved.
// Distributed under the MIT License
// See LICENSE.txt
//
//////////////////////////////////////////////////////////////////////

(function(scope) {
  function initImages(app, inPort="imagesIn", outPort="imagesOut") {
    if (!app) {
      console.log("app is not defined.");
      return;
    }
    var ports = app.ports;
    if (!ports) {
      console.log("app.ports is not defined.");
      return;
    }

    const imagesIn = ports[inPort];
    const imagesOut = ports[outPort];

    if (!imagesIn || !imagesOut) {
      console.log(inPort + " or " + outPort + " port not defined.");
      return;
    }

    // cmd = { id : String, cmd : String, args : [ arg1, arg2, ...] }
    imagesIn.subscribe(function(cmd) {
      const img = document.getElementById(cmd.id);
      if (!img) {
        console.log("Can't find element with id:", cmd.id);
      } else {
        const command = cmd.command;
        const args = cmd.args;
        if (command == 'subImage') {
          var url = args.url;
          // https://search.brave.com/search?q=html+copy+part+of+image&source=desktop&conversation=09d7d894bbd405bd7c8f83606a934b4787f1 says:
          const img = new Image();
          img.src = url;
          img.onload = () => {
            const canvas = document.createElement('canvas');
            const left = args.left;
            const right = args.right;
            const top = args.top
            const bottom = args.bottom;
            height = bottom - top;
            width = right - left;

            canvas.width = width;
            canvas.height = height;

            const ctx = canvas.getContext('2d');
            ctx.drawImage(img, left, top, width, height, 0, 0, width, height);

            canvas.toBlob((blob) => {
              urlOut = canvas.toDataUrl();
            });

            imagesOut.send({ command: cmd,
                             url: url
                           });
          }
        } else {
          console.log("Unknown command: ", command);
        }
      };
    })
  }
  scope.initImages = initImages;
})(this);   // Execute the enclosing function.

