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
  function initImages(app) {
    if (!app) {
      console.log("app is not defined.");
      return;
    }
    var ports = app.ports;
    if (!ports) {
      console.log("app.ports is not defined.");
      return;
    }

    const imagesIn = ports.imagesIn;
    const imagesOut = ports.imagesOut;

    if (!imagesIn || !imagesOut) {
      console.log("imagesIn or imagesOut port not defined.");
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
          var url = "";
          // https://search.brave.com/search?q=html+copy+part+of+image&source=desktop&conversation=09d7d894bbd405bd7c8f83606a934b4787f1 says:
          // const img = new Image();
          // img.src = 'path/to/image.jpg';
          // img.onload = () => {
          //   const canvas = document.createElement('canvas');
          //   const width = 100; // crop width
          //   const height = 100; // crop height
          //   
          //   canvas.width = width;
          //   canvas.height = height;
          //   const ctx = canvas.getContext('2d');
          //   
          // drawImage(image, sx, sy, sWidth, sHeight, dx, dy, dWidth, dHeight)
          //   ctx.drawImage(img, 0, 0, width, height, 0, 0, width, height);
          //   
          //   canvas.toBlob((blob) => {
          //     copyImageToClipboard(blob);
          //   }, 'image/png');
          // };
          imagesOut.send({ cmd: cmd,
                           url: url
                         });

        } else {
          console.log("Unknown command: ", command);
        }
      }
    });
  }

  scope.initImages = initImages;
})(this);   // Execute the enclosing function.
