module OrigenSWD
  MAJOR = 0
  MINOR = 3
  BUGFIX = 4
  DEV = nil

  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
