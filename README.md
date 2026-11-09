elmcrop

A clone of YellowMug Software's defunct EasyCrop app.

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
    
Requires `rsyncit` from  [wws-scripts](http://github.com/billstclair/wws-scripts) to be in the `PATH`, and `site/.sshdir` to point to a directory you can upload to with `rsync`.


Icon credits:

* Rectangular marquee tool Icon by Custom Icon Design at [Icon-Icons.com](https://icon-icons.com/authors/9-custom-icon-design).
* Window icons created by ranksol graphics at [Flaticon.com](https://Flaticon.com/free-icons/window).
* Share icons created by Bankume at [Flaticon.com](https://www.flaticon.com/free-icons/share")
* Eye In Speech Bubble icon by [icons8.com](https://icons8.com/).
* Other icons from [creative-freedom.co.uk](https://creativefreedom.co.uk/free-icons/1000-free-windows-icons/).

Notes:

[mediabunny.dev](https://mediabunny.dev/guide/introduction) can do the heavy lifting, on things I can't find directly.
