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
  var storage = localStorage;   // could be sessionStorage
  var prefix = "";


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
      var key = cmd.key
      var label = cmd.label;
      if (getOrPut == "put") {
        var val = cmd.value;
        if (!val) {
          storage.removeItem(key);
        } else {
          var str = JSON.stringify(val);
          if (typeof(str) == 'string') {
            storage.setItem(prefix + key, str);
          }
        }
      } else if (getOrPut == "get") {
        try {
          val = JSON.parse(storage.getItem(prefix + key));
        } catch (e) {
        }
        localStorageOut.send(
          { getOrPut: getOrPut, key: key, label: label, value: val }
        );
      } else if (getOrPut == "setprefix") {
        prefix = key;
        localStorageOut.send(
          { getOrPut: getOrPut, key: key, label: label, value: null }
        );
      }
    })
  };

  scope.localstorage = localstorage;
})(this);   // Execute the enclosing function
