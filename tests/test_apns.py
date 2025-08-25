from pushservices.apns import ApnsClient
import unittest
import logging
import sys
from unittest.mock import MagicMock, patch
from util import json_decode


def mocked_httpx_client(*args, **kwargs):
    class Response:
        def __init__(self):
            self.status_code = 200
            self.text = "{}"

    class HTTPXClient:
        def __init__(self, *args, **kwargs):
            pass

        def post(self, path, content, headers):
            return Response()

    return HTTPXClient()


def mocked_jwt_encode(*args, **kwargs):
    return "encode_jwt"


class TestAPNS(unittest.TestCase):
    @patch("jwt.encode", side_effect=mocked_jwt_encode)
    @patch("httpx.Client", side_effect=mocked_httpx_client)
    def test_apns(self, jwt, req):
        self.maxDiff = None
        kwargs = {
            "project_id": "xxx",
            "auth_key": "iiii",
            "bundle_id": "com.airnotifier",
            "key_id": "xxxx",
            "team_id": "xxxx",
            "appname": "",
            "instanceid": "",
        }
        apns = ApnsClient(**kwargs)
        # Reset token cache to ensure mock is used
        apns.token = None
        apns.last_token_refresh = 0
        
        apns_default = {"badge": None, "sound": "default", "push_type": "alert"}
        apns.process(
            token="aaa", alert="alert", apns={**apns_default, **{"badge": 12}},
        )
        self.assertDictEqual(
            apns.headers,
            {
                "apns-expiration": "0",
                "apns-priority": "10",
                "apns-push-type": "alert",
                "apns-topic": "com.airnotifier",
                "authorization": "bearer encode_jwt",
                "mutable-content": "1",
            },
        )
        self.assertEqual(
            apns.payload,
            '{"aps": {"alert": {"body": "alert", "title": "alert"}, "badge": 12, "sound": "default"}}',
        )
        
        # Reset token cache again for second call
        apns.token = None
        apns.last_token_refresh = 0
        
        apns.process(
            token="aaa",
            alert="alert",
            apns={**apns_default, **{"badge": 12, "push_type": "background"}},
        )
        self.assertDictEqual(
            apns.headers,
            {
                "apns-expiration": "0",
                "apns-priority": "10",
                "apns-push-type": "background",
                "apns-topic": "com.airnotifier",
                "authorization": "bearer encode_jwt",
                "mutable-content": "1",
            },
        )


if __name__ == "__main__":
    unittest.main()
