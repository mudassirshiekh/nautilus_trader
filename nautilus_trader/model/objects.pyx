# -------------------------------------------------------------------------------------------------
#  Copyright (C) 2015-2020 Nautech Systems Pty Ltd. All rights reserved.
#  https://nautechsystems.io
#
#  Licensed under the GNU Lesser General Public License Version 3.0 (the "License");
#  You may not use this file except in compliance with the License.
#  You may obtain a copy of the License at https://www.gnu.org/licenses/lgpl-3.0.en.html
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
# -------------------------------------------------------------------------------------------------

"""Define fundamental value objects in the trading domain."""

from nautilus_trader.core.correctness cimport Condition
from nautilus_trader.core.decimal cimport Decimal
from nautilus_trader.model.currency cimport Currency


cdef class Quantity(Decimal):
    """
    Represents a quantity with a non-negative value.

    Capable of storing either a whole number (no decimal places) of “shares”
    (securities denominated in whole units) or a decimal value containing
    decimal places for non-share quantity asset classes (securities denominated
    in fractional units).

    References
    ----------
    https://www.onixs.biz/fix-dictionary/5.0/index.html#Qty

    """

    def __init__(self, value="0", precision=None):
        """
        Initialize a new instance of the Quantity class.

        Parameters
        ----------
        value : integer, float, string, decimal.Decimal or Decimal
            The value of the quantity. If value is a float, then a precision must
            be specified.
        precision : int, optional
            The precision for the quantity. If a precision is specified then the
            value will be rounded to the precision. Else the precision will be
            inferred from the given value.

        Raises
        ------
        TypeError
            If value is a float and precision is not specified.
        ValueError
            If value is negative (< 0).
        ValueError
            If precision is negative (< 0).

        """
        super().__init__(value, precision)

        # Post-condition
        Condition.true(self._value >= 0, f"quantity not negative, was {self._value}")

    cpdef str to_string(self):
        """Return the formatted string representation of this object.

        Returns
        -------
        str

        """
        return f"{self._value:,}"


cdef class Price(Decimal):
    """
    Represents a price in a financial market.

    The number of decimal places may vary. For certain asset classes prices may
    be negative values. For example, prices for options strategies can be
    negative under certain market conditions.

    References
    ----------
    https://www.onixs.biz/fix-dictionary/5.0/index.html#Qty

    """

    def __init__(self, value="0", precision=None):
        """
        Initialize a new instance of the Price class.

        Parameters
        ----------
        value : integer, float, string, decimal.Decimal or Decimal
            The value of the price. If value is a float, then a precision must
            be specified.
        precision : int, optional
            The precision for the price. If a precision is specified then the
            value will be rounded to the precision. Else the precision will be
            inferred from the given value.

        Raises
        ------
        ValueError
            If precision is negative (< 0).

        """
        super().__init__(value, precision)


cdef class Money(Decimal):
    """
    Represents an amount of money including currency type.

    Attributes
    ----------
    currency : Currency
        The currency of the money.

    """

    def __init__(self, value, Currency currency not None):
        """
        Initialize a new instance of the Money class.

        Parameters
        ----------
        value : integer, float, string, decimal.Decimal or Decimal
            The value of the money.
        currency : Currency
            The currency of the money.

        """
        if value is None:
            value = "0"
        super().__init__(value, currency.precision)

        self.currency = currency

    def __eq__(self, Money other) -> bool:
        return self._value == other._value and self.currency == other.currency

    def __ne__(self, Money other) -> bool:
        return not self == other

    def __lt__(self, Money other) -> bool:
        return self._value < other._value and self.currency == other.currency

    def __le__(self, Money other) -> bool:
        return self._value <= other._value and self.currency == other.currency

    def __gt__(self, Money other) -> bool:
        return self._value > other._value and self.currency == other.currency

    def __ge__(self, Money other) -> bool:
        return self._value >= other._value and self.currency == other.currency

    def __hash__(self) -> int:
        return hash((self._value, self.currency))

    def __repr__(self) -> str:
        return f"{self.__class__.__name__}('{self._value}', {self.currency})"

    @property
    def amount(self) -> Decimal:
        """
        Return the amount of money as a decimal.

        Returns
        -------
        Decimal

        """
        return Decimal(self._value)

    cpdef str to_string(self):
        """
        Return the formatted string representation of this object.

        Returns
        -------
        str

        """
        return f"{self._value:,} {self.currency}"
