        function getUrlVars() {
            var vars = {};
            var parts = window.location.href.replace(/[?&]+([^=&]+)=([^&]*)/gi, function(m, key, value) {
                vars[key] = value;
            });
            return vars;
        }

        function httpGetAsync(theUrl, candlestickSeries, volumeSeries, callback) {
            var xmlHttp = new XMLHttpRequest();
            xmlHttp.onreadystatechange = function() {
                if (xmlHttp.readyState == 4 && xmlHttp.status == 200)
                    callback(candlestickSeries, volumeSeries, xmlHttp.responseText);
            }
            xmlHttp.open("GET", theUrl, true); // true for asynchronous 
            xmlHttp.send(null);
        }

        function handleTiker(candlestickSeries, volumeSeries, tickers) {
            //console.log('tickers=', tickers);
            var obj = JSON.parse(tickers);
            //console.log(obj.length);


            var candlestickArray = [];
            var volumeArray = [];
            for (var i = 0; i < obj.length; i++) {
                var item = obj[i];
                var high = parseFloat(item.high) / 1e18;
                var low = parseFloat(item.low) / 1e18;
                var open = parseFloat(item.open) / 1e18;
                var close = parseFloat(item.close) / 1e18;
                var volume = parseFloat(item.volume) / 1e18;
                var time = item.time;
                var candlestickItem = {
                    time: time,
                    open: open,
                    high: high,
                    low: low,
                    close: close
                };
                candlestickArray.push(candlestickItem);

                var volumeItem = {
                    time: time,
                    value: volume,
                    color: open < close ? 'rgba(0, 150, 136, 0.8)' : 'rgba(255,82,82, 0.8)'
                };
                volumeArray.push(volumeItem);
            }
            candlestickSeries.setData(candlestickArray);
            volumeSeries.setData(volumeArray);

            /*
            candlestickSeries.setData([{
                time: "2018-12-19 10:10:11",
                open: 141.77,
                high: 170.39,
                low: 120.25,
                close: 145.72,
                volume: 12
            }, {
                time: "2018-12-29 10:12:11",
                open: 145.72,
                high: 147.99,
                low: 100.11,
                close: 108.19,
                volume: 12
            }, {
                time: "2018-12-29 10:13:11",
                open: 108.19,
                high: 118.43,
                low: 74.22,
                close: 75.16,
                volume: 12
            }, {
                time: "2018-12-19  10:14:11",
                open: 75.16,
                high: 82.84,
                low: 36.16,
                close: 45.72,
                volume: 12
            }]);
            */
        }

        function showChart(pairLeft, pairRight, interval) {
            const chartPrice = LightweightCharts.createChart(document.getElementById('price'), {
                width: window.innerWidth,
                height: window.innerHeight,
                priceScale: {
                    scaleMargins: {
                        top: 0.3,
                        bottom: 0.25,
                    },
                    borderVisible: false,
                },
                layout: {
                    backgroundColor: '#131722',
                    textColor: '#d1d4dc',
                },
                grid: {
                    vertLines: {
                        color: 'rgba(42, 46, 57, 0)',
                    },
                    horzLines: {
                        color: 'rgba(42, 46, 57, 0.6)',
                    },
                },
            });

            const candlestickSeries = chartPrice.addCandlestickSeries({
                overlay: true,
            });

            var volumeSeries = chartPrice.addHistogramSeries({
                color: '#26a69a',
                lineWidth: 2,
                priceFormat: {
                    type: 'volume',
                },
                lastValueVisible: true,
                overlay: true,
                scaleMargins: {
                    top: 0.8,
                    bottom: 0,
                },
            });

            var vars = getUrlVars();
            httpGetAsync('https://kanbantest.fabcoinapi.com/klinedata/' + pairLeft + pairRight + '/' + interval, candlestickSeries, volumeSeries, handleTiker);
            // set data

            /*
            candlestickSeries.setData([{
                time: "2018-12-19",
                open: 141.77,
                high: 170.39,
                low: 120.25,
                close: 145.72,
                volume: 12
            }, {
                time: "2018-12-20",
                open: 145.72,
                high: 147.99,
                low: 100.11,
                close: 108.19,
                volume: 12
            }, {
                time: "2018-12-21",
                open: 108.19,
                high: 118.43,
                low: 74.22,
                close: 75.16,
                volume: 12
            }, {
                time: "2018-12-22",
                open: 75.16,
                high: 82.84,
                low: 36.16,
                close: 45.72,
                volume: 12
            }, {
                time: "2018-12-23",
                open: 45.12,
                high: 53.90,
                low: 45.12,
                close: 48.09,
                volume: 12
            }, {
                time: "2018-12-24",
                open: 60.71,
                high: 60.71,
                low: 53.39,
                close: 59.29,
                volume: 12
            }, {
                time: "2018-12-25",
                open: 68.26,
                high: 68.26,
                low: 59.04,
                close: 60.50,
                volume: 12
            }, {
                time: "2018-12-26",
                open: 67.71,
                high: 105.85,
                low: 66.67,
                close: 91.04,
                volume: 12
            }, {
                time: "2018-12-27",
                open: 91.04,
                high: 121.40,
                low: 82.70,
                close: 111.40,
                volume: 12
            }, {
                time: "2018-12-28",
                open: 111.51,
                high: 142.83,
                low: 103.34,
                close: 131.25,
                volume: 12
            }, {
                time: "2018-12-29",
                open: 131.33,
                high: 151.17,
                low: 77.68,
                close: 96.43,
                volume: 12
            });




            volumeSeries.setData([{
                    time: '2018-12-19',
                    value: 19103293.00,
                    color: 'rgba(0, 150, 136, 0.8)'
                }, {
                    time: '2018-12-20',
                    value: 21737523.00,
                    color: 'rgba(0, 150, 136, 0.8)'
                }, {
                    time: '2018-12-21',
                    value: 29328713.00,
                    color: 'rgba(0, 150, 136, 0.8)'
                }, {
                    time: '2018-12-22',
                    value: 37435638.00,
                    color: 'rgba(0, 150, 136, 0.8)'
                }, {
                    time: '2018-12-23',
                    value: 25269995.00,
                    color: 'rgba(255,82,82, 0.8)'
                }, {
                    time: '2018-12-24',
                    value: 24973311.00,
                    color: 'rgba(255,82,82, 0.8)'
                }, {
                    time: '2018-12-25',
                    value: 22103692.00,
                    color: 'rgba(0, 150, 136, 0.8)'
                }, {
                    time: '2018-12-26',
                    value: 25231199.00,
                    color: 'rgba(0, 150, 136, 0.8)'
                }, {
                    time: '2018-12-27',
                    value: 24214427.00,
                    color: 'rgba(255,82,82, 0.8)'
                }, {
                    time: '2018-12-28',
                    value: 22533201.00,
                    color: 'rgba(255,82,82, 0.8)'
                }, {
                    time: '2018-12-31',
                    value: 14734412.00,
                    color: 'rgba(0, 150, 136, 0.8)'
                },

            ]);
            */
        }