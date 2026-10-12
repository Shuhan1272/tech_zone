from math import ceil

from rest_framework.exceptions import Throttled
from rest_framework.throttling import AnonRateThrottle


class RegisterThrottle(AnonRateThrottle):

    scope = "register"
    
    def throttle_failure(self):

        wait = self.wait()

        minutes = ceil(wait / 60)

        raise Throttled(
            detail=f"Too many registration attempts. Please try again after {minutes} minute(s)."
        )

class LoginThrottle(AnonRateThrottle):

    scope = "login"

    def throttle_failure(self):

        wait = self.wait()

        minutes = ceil(wait / 60)

        raise Throttled(
            detail=f"Too many login attempts. Please try again after {minutes} minute(s)."
        )

class ForgotPasswordThrottle(AnonRateThrottle):

    scope = "forgot_password"

    def throttle_failure(self):

        wait = self.wait()

        minutes = ceil(wait / 60)

        raise Throttled(
            detail=f"Too many forgot password attempts. Please try again after {minutes} minute(s)."
        )

