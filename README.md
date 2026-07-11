ElmCrop

A clone of YelloMug Software's defunct EasyCrop app.

For development:

    $ cd .../elmcrop
    $ elm reactor
    
Then aim your web browser at http://localhost:8000/site/index.html.

After making changes:

    $ cd .../elmcrop
    $ bin/build
    
Then fully refresh your browser, to run the new code.

To upload to the directory specified by `site/.sshdir`:

    $ cd .../elmcrop
    $ bin/update-site
    
Requires `rsyncit` from  [wws-scripts](http://github.com/billstclair/wws-scripts) to be in the `PATH`, and `.sshdir` to point to a directory you can upload to with `rsync`.
