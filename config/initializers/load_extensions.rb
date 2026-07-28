require Rails.root.join("lib/extensions/big_decimal")

BigDecimal.include(Extensions::BigDecimal)
