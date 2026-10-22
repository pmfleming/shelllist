//! Schema-2 metric encoding: [descriptor index, value, optional reason index].
//! Units, sources and repeated unavailable reasons live once in the manifest.
//! Counter integers remain JSON u64 values; no float round-trip is introduced.
use anyhow::{Context, Result, ensure};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SampleSchema {
    pub descriptors: Vec<Descriptor>,
    pub unavailable_reasons: Vec<String>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Descriptor {
    pub unit: String,
    pub source: String,
}

impl SampleSchema {
    pub fn validate(&self) -> Result<()> {
        ensure!(
            self.descriptors.len() <= 4096 && self.unavailable_reasons.len() <= 16384,
            "sample schema dictionary limit exceeded"
        );
        Ok(())
    }

    pub fn compact(&mut self, value: &mut Value) -> Result<()> {
        match value {
            Value::Object(fields)
                if fields.len() == 4
                    && ["unit", "source", "value", "reason"]
                        .iter()
                        .all(|key| fields.contains_key(*key)) =>
            {
                let descriptor = Descriptor {
                    unit: fields["unit"]
                        .as_str()
                        .context("invalid metric unit")?
                        .into(),
                    source: fields["source"]
                        .as_str()
                        .context("invalid metric source")?
                        .into(),
                };
                let id = self
                    .descriptors
                    .iter()
                    .position(|d| d == &descriptor)
                    .unwrap_or_else(|| {
                        self.descriptors.push(descriptor);
                        self.descriptors.len() - 1
                    });
                let mut parts = vec![json!(id), fields.remove("value").unwrap()];
                if let Some(reason) = fields["reason"].as_str() {
                    let index = self
                        .unavailable_reasons
                        .iter()
                        .position(|s| s == reason)
                        .unwrap_or_else(|| {
                            self.unavailable_reasons.push(reason.into());
                            self.unavailable_reasons.len() - 1
                        });
                    parts.push(json!(index));
                }
                *value = Value::Array(parts);
                self.validate()?;
            }
            Value::Object(fields) => {
                for value in fields.values_mut() {
                    self.compact(value)?;
                }
            }
            Value::Array(values) => {
                for value in values {
                    self.compact(value)?;
                }
            }
            _ => {}
        }
        Ok(())
    }

    pub fn expand(&self, value: &mut Value) -> Result<()> {
        match value {
            // All other arrays in Sample contain objects, not scalar tuples.
            Value::Array(parts) if parts.first().is_some_and(Value::is_number) => {
                ensure!(
                    parts.len() == 2 || parts.len() == 3,
                    "invalid compact metric length"
                );
                let id = usize::try_from(parts[0].as_u64().context("invalid descriptor index")?)?;
                let descriptor = self
                    .descriptors
                    .get(id)
                    .context("unknown metric descriptor")?;
                let reason = if parts.len() == 3 {
                    let id = usize::try_from(parts[2].as_u64().context("invalid reason index")?)?;
                    Some(
                        self.unavailable_reasons
                            .get(id)
                            .context("unknown unavailable reason")?,
                    )
                } else {
                    None
                };
                ensure!(
                    parts[1].is_null() == reason.is_some(),
                    "compact metric must have value or reason"
                );
                *value = json!({"unit":descriptor.unit,"source":descriptor.source,"value":parts[1],"reason":reason});
            }
            Value::Object(fields) => {
                for value in fields.values_mut() {
                    self.expand(value)?;
                }
            }
            Value::Array(values) => {
                for value in values {
                    self.expand(value)?;
                }
            }
            _ => {}
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn compact_metrics_preserve_full_width_integers_unknowns_and_reject_bad_references() {
        let original = json!({"counters": {
            "a": {"value":u64::MAX,"unit":"bytes","source":"fixture","reason":null},
            "b": {"value":null,"unit":"bytes","source":"fixture","reason":"denied"}
        }});
        let mut schema = SampleSchema::default();
        let mut compact = original.clone();
        schema.compact(&mut compact).unwrap();
        assert_eq!(schema.descriptors.len(), 1);
        assert_eq!(schema.unavailable_reasons, ["denied"]);
        let mut restored = compact.clone();
        schema.expand(&mut restored).unwrap();
        assert_eq!(restored, original);
        for bad in [
            json!([99, 1]),
            json!([0, null]),
            json!([0, null, 99]),
            json!([0, 1, 0]),
            json!([0, 1, 0, 0]),
        ] {
            assert!(schema.expand(&mut bad.clone()).is_err());
        }
    }
}
