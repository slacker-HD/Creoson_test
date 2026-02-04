
// Define the Module
var creo = creo || {};

creo.ajax = (function (pub) {

        if (typeof jQuery === "undefined") {
            // If we're in Node.js provide a simple http-based implementation; otherwise require jQuery
            if (typeof module !== 'undefined' && module.exports) {
                pub.sessionId = -1;
                pub.url  =  '/creoson';
                pub.port =  9056;
                pub.dataType =  "json";          
                pub.type =  'post';
                pub.traditional = true;

                pub.lastRequestObj = {};

                pub.request = function(dataObj) {
                    console.log('got into : creo.ajax request (node fallback)');

                    return new Promise(function (resolve, reject) {

                        if (pub.sessionId !== -1) {
                            dataObj.sessionId = pub.sessionId;
                        }

                        const postData = JSON.stringify(dataObj);

                        const options = {
                            hostname: 'localhost',
                            port: pub.port,
                            path: pub.url,
                            method: 'POST',
                            headers: {
                                'Content-Type': 'application/json',
                                'Content-Length': Buffer.byteLength(postData)
                            }
                        };

                        const req = require('http').request(options, (res) => {
                            let body = '';
                            res.setEncoding('utf8');
                            res.on('data', (chunk) => { body += chunk; });
                            res.on('end', () => {
                                try {
                                    const data = JSON.parse(body);

                                    if (data.status && data.status.error) {
                                        if (data.status.hasOwnProperty('message')) {
                                            return reject(data.status.message);
                                        } else {
                                            return reject('creoson Operation failed! - check server');
                                        }
                                    } else {
                                        if (dataObj.command === 'connection' && dataObj.function === 'connect' && data.sessionId) {
                                            console.log('automatically setting the sessionId : ' + data.sessionId);
                                            pub.sessionId = data.sessionId;
                                        }
                                        return resolve(data);
                                    }

                                } catch (err) {
                                    return reject(err);
                                }
                            });
                        });

                        req.on('error', (e) => { reject(e); });
                        req.write(postData);
                        req.end();
                    });
                };

            } else {
                alert('creo.ajax requires the jQuery Library to be loaded in your HTML file!');
                throw('creo.ajax requires the jQuery Library to be loaded in your HTML file!');
            }
        } else {

            pub.sessionId = -1;
            pub.url  =  '/creoson';
            pub.port =  9056;
            pub.dataType =  "json";          
            pub.type =  'post';
            pub.traditional = true;

            pub.lastRequestObj = {};
            
            pub.request = function(dataObj) {
                console.log('got into : creo.ajax request');

                return new Promise(function (resolve, reject) {

                    if (pub.sessionId !== -1) {
                        dataObj.sessionId = pub.sessionId;
                    }

                    // define the default request - inherit current pub vars
                    let requestObjConst = {
                        url: pub.url,
                        port: pub.port,
                        dataType: pub.dataType,
                        type: pub.type,
                        async : false,
                        traditional: pub.traditional,
                        data: null
                    };

                    requestObjConst.data = JSON.stringify(dataObj); // set the transaction to the request object

                    pub.lastRequestObj = requestObjConst;  // expose the request

                    // log the request to the console
                    console.log(JSON.stringify(requestObjConst, null, 2));
                    $.ajax(
                        requestObjConst
                    )
                        .done(function (data) {

                            if (data.status.error) {

                                console.log('---- ERROR -----');
                                console.log(JSON.stringify(data, null, 2));

                                if (data.status.hasOwnProperty('message')) {
                                    reject(data.status.message);
                                } else {
                                    reject('creoson Operation failed! - check console for details');
                                }


                            } else {

                                if (dataObj.command === 'connection' && dataObj.function === 'connect') {
                                    console.log('automatically setting the sessionId : '+data.sessionId);
                                    pub.sessionId = data.sessionId;
                                }

                                resolve(data);
                            }

                        })
                        .fail(function (e) {
                            // reject('creoson Operation failed! - check console for details');
                            reject(e);
                        });

                })
            };

        }

    return pub;

}(creo.ajax || {}));

if (typeof module !== 'undefined' && module.exports) {
    module.exports = creo;
} 