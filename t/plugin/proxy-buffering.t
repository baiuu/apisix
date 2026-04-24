#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
use t::APISIX;

my $nginx_binary = $ENV{'TEST_NGINX_BINARY'} || 'nginx';
my $version = eval { `$nginx_binary -V 2>&1` };

if ($version !~ m/\apisix-nginx-module/) {
    plan(skip_all => "apisix-nginx-module not installed");
} else {
    plan('no_plan');
}

repeat_each(1);
log_level('info');
no_root_location();
no_shuffle();

add_block_preprocessor(sub {
    my ($block) = @_;

    if (!$block->request) {
        $block->set_value("request", "GET /t");
    }
});

run_tests();

__DATA__

=== TEST 1: set proxy-buffering off
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin").test
            local json = require("toolkit.json")
            local code, body = t('/apisix/admin/routes/1',
                ngx.HTTP_PUT,
                [[{
                    "uri": "/hello",
                    "upstream": {
                        "type": "roundrobin",
                        "nodes": {
                            "127.0.0.1:1980": 1
                        }
                    },
                    "plugins": {
                        "proxy-buffering": {
                            "enable": false
                        }
                    }
            }]]
            )

        if code >= 300 then
            ngx.status = code
        end
        ngx.say(body)
    }
}
--- response_body
passed



=== TEST 2: hit, proxy_buffering off
--- http_config
    proxy_buffer_size 1k;
    proxy_buffers 2 1k;
--- upstream_server_config
    location /hello {
        content_by_lua_block {
            ngx.print(string.rep("x", 10240))
        }
    }
--- request
GET /hello
--- grep_error_log eval
qr/an upstream response is buffered to a temporary file/
--- grep_error_log_out



=== TEST 3: set proxy-buffering on
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin").test
            local json = require("toolkit.json")
            local code, body = t('/apisix/admin/routes/1',
                ngx.HTTP_PUT,
                [[{
                    "uri": "/hello",
                    "upstream": {
                        "type": "roundrobin",
                        "nodes": {
                            "127.0.0.1:1980": 1
                        }
                    },
                    "plugins": {
                        "proxy-buffering": {
                            "enable": true
                        }
                    }
            }]]
            )

        if code >= 300 then
            ngx.status = code
        end
        ngx.say(body)
    }
}
--- response_body
passed



=== TEST 4: hit, proxy_buffering on
--- http_config
    proxy_buffer_size 1k;
    proxy_buffers 2 1k;
--- upstream_server_config
    location /hello {
        content_by_lua_block {
            ngx.print(string.rep("x", 10240))
        }
    }
--- request
GET /hello
--- grep_error_log eval
qr/an upstream response is buffered to a temporary file/
--- grep_error_log_out
an upstream response is buffered to a temporary file
