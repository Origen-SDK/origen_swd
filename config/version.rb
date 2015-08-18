module OrigenSWD
  MAJOR = 0
  MINOR = 3
  BUGFIX = 3
  DEV = nil

  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
