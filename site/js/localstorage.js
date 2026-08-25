//////////////////////////////////////////////////////////////////////
//
// LocalStorage.js
// JavaScript runtime code for LocalStorage read/write.
// Copyright (c) 2026 Bill St. Clair <billstclair@gmail.com>
// Some rights reserved.
// Distributed under the MIT License
// See LICENSE.txt
//
//////////////////////////////////////////////////////////////////////

(function(scope) {
  function localstorage(app) {
    if (!app) {
      console.log("app is not defined.");
      return;
    }
    var ports = app.ports
    if (!ports) {
      console.log("app.ports is not defined.");
      return;
    }

    var localStorageIn = ports.localStorageIn;
    var localStorageOut = ports.localStorageOut;

    if (!localStorageIn || !localStorageOut) {
      console.log("localStorageIn or localStorageOut port not defined.");
      return;
    }

    localStorageIn.subscribe(function(cmd) {
      var getOrPut = cmd.getOrPut;
      var label = cmd.label;
      var key = cmd.key
      if (getOrPut == "put") {
        var val = cmd.val;
        if (!val) {
          storage.removeItem(key);
        } else {
          var str = JSON.stringify(val);
          if (typeof(str) == 'string') {
            storage.setItem(key, str);
          }
        }
      } else if (getOrPut == "get") {
        try {
          val = JSON.parse(storage.getItem(key));
        } catch (e) {
        }
        localStorageOut.send({ label: label, key: key, val: val })
      }
    })
  };

  scope.localstorage = localstorage;
})(this);   // Execute the enclosing function
