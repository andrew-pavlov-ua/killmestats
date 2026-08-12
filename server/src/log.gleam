import logging

pub fn debug(message: String) -> Nil {
  logging.log(logging.Debug, message)
}

pub fn info(message: String) -> Nil {
  logging.log(logging.Info, message)
}

pub fn warning(message: String) -> Nil {
  logging.log(logging.Warning, message)
}

pub fn error(message: String) -> Nil {
  logging.log(logging.Error, message)
}
