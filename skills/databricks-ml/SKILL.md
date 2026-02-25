---
name: databricks-ml
description: Specialized skill for Databricks Machine Learning workflows including MLflow experiment tracking, model registry, Feature Store, and CI/CD with Databricks Asset Bundles. Covers best practices for production ML pipelines.
---

# Databricks Machine Learning

A specialized skill for developing, tracking, and deploying machine learning models on Databricks using MLflow, Unity Catalog, Feature Store, and Databricks Asset Bundles for CI/CD.

## Overview

This skill helps you build production-grade machine learning pipelines on Databricks, leveraging MLflow for experiment tracking and model management, Unity Catalog for governance, and Databricks Asset Bundles for infrastructure-as-code deployment.

## Responsibilities

1. Configure and manage MLflow experiments and runs
2. Implement model tracking with autologging and custom logging
3. Register and manage models in Unity Catalog Model Registry
4. Design and implement feature engineering with Databricks Feature Store
5. Structure Databricks Asset Bundles for ML projects
6. Implement CI/CD pipelines for ML workflows
7. Apply best practices for reproducibility and governance
8. Optimize distributed training and model serving
9. Set up model monitoring and alerting
10. Ensure security and compliance for ML assets

## Key Technologies

### MLflow
- **Experiment Tracking**: Log parameters, metrics, artifacts, and models
- **Model Registry**: Version control and lifecycle management
- **Model Serving**: Deploy models as REST APIs
- **Autologging**: Automatic logging for sklearn, TensorFlow, PyTorch, XGBoost, LightGBM
- **Model Signatures**: Define input/output schemas
- **Unity Catalog Integration**: Three-level namespace (catalog.schema.model)

### Databricks Packages
- `mlflow`: Core MLflow library (pre-installed on Databricks)
- `databricks-feature-engineering`: Feature Store SDK
- `databricks-sdk`: Databricks SDK for Python
- `hyperopt`: Distributed hyperparameter tuning with SparkTrials
- `databricks-automl-runtime`: AutoML capabilities

### ML Frameworks
- scikit-learn, pandas, numpy (standard ML stack)
- TensorFlow, PyTorch (deep learning)
- XGBoost, LightGBM, CatBoost (gradient boosting)
- Spark MLlib (distributed ML)
- Horovod (distributed training)

## Commands

### setup-mlflow-experiment

Initialize MLflow experiment with best practices.

**Steps:**
1. Create or set MLflow experiment with descriptive name
2. Configure experiment tags (project, team, use_case)
3. Set up Unity Catalog integration if available
4. Enable autologging for the framework
5. Configure artifact location (DBFS or UC volumes)
6. Set up parent run for organizing multiple runs
7. Document experiment purpose and goals
8. Example code:
   ```python
   import mlflow

   # Set experiment (creates if doesn't exist)
   mlflow.set_experiment("/Users/{username}/project-name")

   # Enable autologging
   mlflow.sklearn.autolog()  # or tensorflow, pytorch, xgboost

   # Set experiment tags
   mlflow.set_experiment_tags({
       "project": "customer-churn",
       "team": "data-science",
       "model_type": "classification"
   })
   ```

### track-ml-run

Log parameters, metrics, and artifacts for an ML run.

**Steps:**
1. Start MLflow run with descriptive name
2. Log all hyperparameters (learning_rate, n_estimators, etc.)
3. Log dataset information (size, features, target distribution)
4. Log metrics during training (loss, accuracy, F1, AUC)
5. Log final evaluation metrics
6. Log confusion matrix and feature importance as artifacts
7. Log model with signature and input example
8. Tag run with relevant metadata (git_commit, environment)
9. Log custom artifacts (plots, reports, preprocessors)
10. Example structure:
    ```python
    with mlflow.start_run(run_name="xgboost-experiment-1") as run:
        # Log parameters
        mlflow.log_params({
            "max_depth": 6,
            "learning_rate": 0.1,
            "n_estimators": 100
        })

        # Train model
        model.fit(X_train, y_train)

        # Log metrics
        mlflow.log_metrics({
            "train_accuracy": train_acc,
            "test_accuracy": test_acc,
            "f1_score": f1
        })

        # Log model with signature
        signature = mlflow.models.infer_signature(X_test, predictions)
        mlflow.sklearn.log_model(
            model,
            "model",
            signature=signature,
            input_example=X_test.iloc[:5]
        )
    ```

### register-model-uc

Register model to Unity Catalog Model Registry.

**Steps:**
1. Verify Unity Catalog is enabled
2. Choose three-level namespace (catalog.schema.model_name)
3. Log model from training run with proper signature
4. Register logged model to Unity Catalog
5. Add model version description and tags
6. Set model alias (e.g., "champion", "challenger")
7. Document model lineage (dataset, features, preprocessing)
8. Add model metadata (use_case, owner, approval_status)
9. Example:
   ```python
   # Log model
   mlflow.sklearn.log_model(
       model,
       artifact_path="model",
       registered_model_name="main.ml_models.churn_classifier"
   )

   # Or register existing run
   model_uri = f"runs:/{run_id}/model"
   model_version = mlflow.register_model(
       model_uri,
       "main.ml_models.churn_classifier"
   )

   # Set alias
   client = mlflow.tracking.MlflowClient()
   client.set_registered_model_alias(
       "main.ml_models.churn_classifier",
       "champion",
       model_version.version
   )
   ```

### manage-model-lifecycle

Transition models through stages in Unity Catalog.

**Steps:**
1. Review model performance metrics
2. Test model on validation dataset
3. Update model version tags and description
4. Set appropriate alias (challenger, champion)
5. Archive old model versions if needed
6. Document transition rationale
7. Notify stakeholders of model promotion
8. Set up model monitoring (if promoting to production)
9. Example workflow:
   ```python
   client = mlflow.tracking.MlflowClient()

   # Get model by alias
   model_version = client.get_model_version_by_alias(
       "main.ml_models.churn_classifier",
       "challenger"
   )

   # After validation, promote to champion
   client.set_registered_model_alias(
       "main.ml_models.churn_classifier",
       "champion",
       model_version.version
   )

   # Archive old champion
   client.delete_registered_model_alias(
       "main.ml_models.churn_classifier",
       "champion_v2"
   )
   ```

### setup-feature-store

Implement feature engineering with Databricks Feature Store.

**Steps:**
1. Install databricks-feature-engineering package
2. Design feature table schema with primary keys
3. Create feature table in Unity Catalog
4. Implement feature computation logic
5. Write features to feature table with timestamps
6. Set up feature table metadata (description, tags)
7. Create training dataset with feature lookups
8. Log model with feature dependencies
9. Enable online feature serving if needed
10. Example:
    ```python
    from databricks.feature_engineering import FeatureEngineeringClient

    fe = FeatureEngineeringClient()

    # Create feature table
    fe.create_table(
        name="main.features.customer_features",
        primary_keys=["customer_id"],
        timestamp_keys=["timestamp"],
        schema=features_df.schema,
        description="Customer aggregated features for churn prediction"
    )

    # Write features
    fe.write_table(
        name="main.features.customer_features",
        df=features_df,
        mode="merge"
    )

    # Create training set with feature lookups
    training_set = fe.create_training_set(
        df=labels_df,
        feature_lookups=[
            FeatureLookup(
                table_name="main.features.customer_features",
                lookup_key="customer_id"
            )
        ],
        label="churn"
    )
    ```

### setup-databricks-bundle

Create Databricks Asset Bundle for ML project.

**Steps:**
1. Initialize bundle structure: `databricks bundle init`
2. Create `databricks.yml` in project root
3. Define bundle name and resources
4. Configure environments (dev, staging, prod)
5. Define workspace paths per environment
6. Configure jobs for training and inference
7. Set up notebook tasks or Python wheel tasks
8. Configure job clusters with appropriate instance types
9. Define job parameters and dependencies
10. Add UC permissions and access controls
11. Example `databricks.yml`:
    ```yaml
    bundle:
      name: ml-churn-prediction

    include:
      - resources/*.yml

    workspace:
      root_path: /Workspace/${workspace.current_user.userName}/.bundle/${bundle.name}/${bundle.target}

    targets:
      dev:
        mode: development
        workspace:
          host: https://your-workspace.cloud.databricks.com
        variables:
          catalog: dev
          schema: ml_models

      prod:
        mode: production
        workspace:
          host: https://your-workspace.cloud.databricks.com
        variables:
          catalog: main
          schema: ml_models
        run_as:
          service_principal_name: sp-ml-prod
    ```

### configure-bundle-resources

Define ML pipeline resources in Asset Bundle.

**Steps:**
1. Create `resources/training_job.yml`
2. Define training job with tasks
3. Configure job clusters (use job clusters, not all-purpose)
4. Set up job schedule/triggers
5. Define job parameters (data paths, model names)
6. Configure email alerts on failure
7. Set up dependencies between tasks
8. Configure retry policies
9. Example training job:
    ```yaml
    resources:
      jobs:
        churn_model_training:
          name: churn-model-training-${bundle.target}

          tasks:
            - task_key: feature_engineering
              notebook_task:
                notebook_path: ../notebooks/feature_engineering.py
                base_parameters:
                  catalog: ${var.catalog}
                  schema: ${var.schema}
              new_cluster:
                spark_version: 14.3.x-scala2.12
                node_type_id: i3.xlarge
                num_workers: 2
                spark_conf:
                  "spark.databricks.delta.preview.enabled": "true"

            - task_key: train_model
              depends_on:
                - task_key: feature_engineering
              python_wheel_task:
                package_name: churn_model
                entry_point: train
                parameters:
                  - "--catalog=${var.catalog}"
                  - "--schema=${var.schema}"
              new_cluster:
                spark_version: 14.3.x-ml-scala2.12
                node_type_id: i3.xlarge
                num_workers: 2
              libraries:
                - pypi:
                    package: mlflow>=2.9.0
                - pypi:
                    package: databricks-feature-engineering

          schedule:
            quartz_cron_expression: "0 0 2 * * ?"
            timezone_id: "America/New_York"

          email_notifications:
            on_failure:
              - ml-team@company.com
    ```

### implement-bundle-cicd

Set up CI/CD pipeline for Databricks Asset Bundle.

**Steps:**
1. Create `.github/workflows/` or `.gitlab-ci.yml`
2. Set up Databricks authentication (service principal)
3. Install Databricks CLI in CI environment
4. Validate bundle on PR: `databricks bundle validate`
5. Run unit tests for Python code
6. Deploy to dev on merge to main
7. Run integration tests in dev
8. Deploy to prod on tag/release
9. Implement approval gates for prod deployment
10. Store secrets securely (GitHub Secrets, Azure Key Vault)
11. Example GitHub Actions workflow:
    ```yaml
    name: Deploy ML Pipeline

    on:
      push:
        branches: [main]
      pull_request:
        branches: [main]

    jobs:
      validate:
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v3

          - name: Setup Databricks CLI
            run: |
              curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh

          - name: Validate Bundle
            env:
              DATABRICKS_HOST: ${{ secrets.DATABRICKS_HOST }}
              DATABRICKS_TOKEN: ${{ secrets.DATABRICKS_TOKEN }}
            run: |
              databricks bundle validate -t dev

      deploy-dev:
        needs: validate
        if: github.event_name == 'push'
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v3

          - name: Deploy to Dev
            env:
              DATABRICKS_HOST: ${{ secrets.DATABRICKS_HOST }}
              DATABRICKS_TOKEN: ${{ secrets.DATABRICKS_TOKEN }}
            run: |
              databricks bundle deploy -t dev
              databricks bundle run -t dev churn_model_training

      deploy-prod:
        needs: validate
        if: startsWith(github.ref, 'refs/tags/v')
        runs-on: ubuntu-latest
        environment: production
        steps:
          - uses: actions/checkout@v3

          - name: Deploy to Prod
            env:
              DATABRICKS_HOST: ${{ secrets.DATABRICKS_HOST }}
              DATABRICKS_TOKEN: ${{ secrets.DATABRICKS_TOKEN }}
            run: |
              databricks bundle deploy -t prod
    ```

### optimize-distributed-training

Implement distributed training patterns on Databricks.

**Steps:**
1. Choose distribution strategy (Horovod, TorchDistributor, TensorFlow distributed)
2. Configure cluster with GPU nodes if needed
3. Implement data loading with proper partitioning
4. Set up distributed training code
5. Configure Horovod with `hvd.DistributedOptimizer`
6. Use `SparkTrials` for distributed hyperparameter tuning with Hyperopt
7. Monitor GPU utilization and scaling efficiency
8. Log distributed metrics to MLflow
9. Example Horovod + MLflow:
    ```python
    import horovod.tensorflow as hvd
    import mlflow

    hvd.init()

    # Only log on rank 0
    if hvd.rank() == 0:
        mlflow.start_run()

    # Horovod distributed optimizer
    optimizer = hvd.DistributedOptimizer(optimizer)

    # Train model
    model.fit(...)

    if hvd.rank() == 0:
        mlflow.tensorflow.log_model(model, "model")
        mlflow.end_run()
    ```

### setup-hyperparameter-tuning

Implement distributed hyperparameter tuning with Hyperopt.

**Steps:**
1. Define search space using `hp.choice`, `hp.uniform`, etc.
2. Create objective function that returns loss metric
3. Use MLflow callback for tracking trials
4. Configure SparkTrials for distributed search
5. Set parallelism based on cluster size
6. Run `fmin` with TPE algorithm
7. Retrieve best parameters and model
8. Register best model to Unity Catalog
9. Example:
    ```python
    from hyperopt import fmin, tpe, hp, SparkTrials, STATUS_OK
    import mlflow

    search_space = {
        'max_depth': hp.quniform('max_depth', 3, 10, 1),
        'learning_rate': hp.loguniform('learning_rate', -5, 0),
        'n_estimators': hp.quniform('n_estimators', 50, 300, 10)
    }

    def objective(params):
        with mlflow.start_run(nested=True):
            mlflow.log_params(params)

            model = XGBClassifier(**params)
            model.fit(X_train, y_train)

            accuracy = model.score(X_test, y_test)
            mlflow.log_metric("accuracy", accuracy)

            return {'loss': -accuracy, 'status': STATUS_OK}

    # Distributed trials
    spark_trials = SparkTrials(parallelism=4)

    with mlflow.start_run(run_name="hyperopt-tuning"):
        best_params = fmin(
            fn=objective,
            space=search_space,
            algo=tpe.suggest,
            max_evals=100,
            trials=spark_trials
        )
    ```

### deploy-model-serving

Deploy model for real-time inference using Databricks Model Serving.

**Steps:**
1. Ensure model is registered in Unity Catalog
2. Navigate to Serving in Databricks UI or use API
3. Create serving endpoint with model URI
4. Configure endpoint compute (size and scale)
5. Set up environment variables and secrets
6. Enable autoscaling and monitoring
7. Test endpoint with sample requests
8. Set up endpoint authentication
9. Document API usage for consumers
10. Example using Databricks SDK:
    ```python
    from databricks.sdk import WorkspaceClient

    w = WorkspaceClient()

    # Create serving endpoint
    w.serving_endpoints.create(
        name="churn-prediction-endpoint",
        config={
            "served_entities": [{
                "entity_name": "main.ml_models.churn_classifier",
                "entity_version": "1",
                "workload_size": "Small",
                "scale_to_zero_enabled": True
            }]
        }
    )

    # Query endpoint
    response = w.serving_endpoints.query(
        name="churn-prediction-endpoint",
        dataframe_records=[{
            "feature1": value1,
            "feature2": value2
        }]
    )
    ```

### implement-model-monitoring

Set up monitoring for production models.

**Steps:**
1. Enable Lakehouse Monitoring on inference tables
2. Log prediction inputs and outputs
3. Set up data drift detection
4. Monitor model performance metrics (accuracy, latency)
5. Create alerts for drift or performance degradation
6. Track feature distribution changes
7. Log ground truth labels when available
8. Create monitoring dashboard
9. Set up notification channels (email, Slack)
10. Example monitoring setup:
    ```python
    # Log predictions with inputs for monitoring
    predictions_df = spark.createDataFrame([
        {
            "customer_id": cust_id,
            "prediction": pred,
            "prediction_timestamp": timestamp,
            **input_features
        }
        for cust_id, pred in zip(customer_ids, predictions)
    ])

    predictions_df.write.format("delta").mode("append") \
        .saveAsTable("main.monitoring.churn_predictions")

    # Enable Lakehouse Monitoring
    # (via UI or API)
    ```

## Best Practices

### Reproducibility
- Always log complete environment (requirements.txt, conda.yml)
- Pin package versions in production
- Use MLflow model signatures for input validation
- Log data versions and feature definitions
- Tag runs with git commit SHA
- Use Databricks Jobs for scheduled training (not ad-hoc notebooks)

### Model Governance
- Use Unity Catalog for centralized model registry
- Implement approval workflows for model promotion
- Document model cards (use case, limitations, bias testing)
- Set up lineage tracking (data → features → model)
- Tag models with owner, team, compliance status
- Archive deprecated models, don't delete

### Security & Compliance
- Use service principals for CI/CD, not personal tokens
- Store secrets in Databricks Secrets or Azure Key Vault
- Implement RBAC with Unity Catalog
- Audit model access and usage
- Encrypt sensitive features
- Comply with data retention policies

### Performance Optimization
- Use job clusters, not all-purpose clusters (50-75% cost savings)
- Right-size clusters (don't over-provision)
- Use autoscaling for variable workloads
- Cache frequently accessed feature tables
- Use Delta Lake for features (ACID + time travel)
- Implement incremental feature computation

### Testing Strategy
- Unit test feature engineering logic
- Validate feature schema changes
- Test model inference code
- Integration test full pipeline in dev
- Validate bundle deployment before prod
- Monitor model performance post-deployment

### CI/CD Best Practices
- Use Databricks Asset Bundles for infrastructure-as-code
- Separate environments (dev, staging, prod)
- Implement approval gates for prod
- Run automated tests in CI
- Use service principals per environment
- Version control everything (code, configs, notebooks)
- Automate deployment, manual approval only for prod

### Code Organization
```
ml-project/
├── databricks.yml              # Bundle configuration
├── resources/
│   ├── training_job.yml       # Training job definition
│   └── inference_job.yml      # Batch inference job
├── src/
│   ├── features/              # Feature engineering
│   ├── models/                # Model training code
│   ├── utils/                 # Shared utilities
│   └── __init__.py
├── notebooks/                  # Exploration notebooks
├── tests/                      # Unit and integration tests
├── requirements.txt            # Python dependencies
└── README.md                   # Documentation
```

## Common Patterns

### Pattern 1: Feature Store + MLflow Training
```python
from databricks.feature_engineering import FeatureEngineeringClient
import mlflow

fe = FeatureEngineeringClient()

# Create training set with feature lookups
training_set = fe.create_training_set(
    df=labels_df,
    feature_lookups=[...],
    label="target"
)

training_df = training_set.load_df()

# Train and log model with feature dependencies
with mlflow.start_run():
    model = train_model(training_df)

    fe.log_model(
        model=model,
        artifact_path="model",
        flavor=mlflow.sklearn,
        training_set=training_set,
        registered_model_name="main.ml_models.my_model"
    )
```

### Pattern 2: Batch Inference with Feature Lookup
```python
# Score new data with automatic feature lookup
predictions = fe.score_batch(
    model_uri=f"models:/main.ml_models.my_model@champion",
    df=new_customers_df
)
```

### Pattern 3: Environment-Specific Config
```python
# In training code
import os

catalog = os.environ.get("CATALOG", "dev")
schema = os.environ.get("SCHEMA", "ml_models")

model_name = f"{catalog}.{schema}.churn_classifier"
mlflow.register_model(model_uri, model_name)
```

## Troubleshooting

### MLflow Issues
- **Problem**: Model not found in Unity Catalog
  - **Solution**: Check three-level namespace, verify UC is enabled, check permissions

- **Problem**: Autologging not capturing metrics
  - **Solution**: Call `autolog()` before training, check framework compatibility

### Bundle Deployment
- **Problem**: `databricks bundle deploy` fails
  - **Solution**: Validate first with `databricks bundle validate`, check credentials, verify workspace path permissions

- **Problem**: Job fails after bundle deployment
  - **Solution**: Check job logs, verify libraries installed, check cluster config

### Feature Store
- **Problem**: Feature lookup fails at inference
  - **Solution**: Ensure primary keys match, check timestamp alignment, verify feature table exists

## Resources

- [MLflow Documentation](https://mlflow.org/docs/latest/index.html)
- [Databricks ML Guide](https://docs.databricks.com/machine-learning/index.html)
- [Databricks Asset Bundles](https://docs.databricks.com/dev-tools/bundles/index.html)
- [Unity Catalog ML](https://docs.databricks.com/machine-learning/manage-model-lifecycle/index.html)
- [Feature Engineering in Unity Catalog](https://docs.databricks.com/machine-learning/feature-store/index.html)

## Example Usage

When invoked, this skill will help with:

```bash
# Example invocations (conceptual)
/databricks-ml setup-mlflow-experiment
/databricks-ml track-ml-run
/databricks-ml register-model-uc
/databricks-ml setup-databricks-bundle
/databricks-ml implement-bundle-cicd
```

The skill provides guidance, code examples, and best practices for each command to help you build production-grade ML pipelines on Databricks.
